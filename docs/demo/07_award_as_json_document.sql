-- DEMO 7 - One Award as a single integration payload.
--
-- This is the query to run when the question is "what does Huron actually receive?".
-- It returns one complete Award as a nested JSON document - root fields, BU
-- extension, hierarchy placement, people, money, terms, special reviews and BU
-- custom fields - with no Cartesian multiplication. Each collection is a correlated
-- subquery feeding JSON_ARRAYAGG, so persons x terms x customFields never
-- cross-multiply.
--
-- Two things worth pointing at while it is on screen:
--
--   sourceKeys   Every KC identifier needed to tie the loaded record back to KC and
--                to re-link it to other objects. This is the D-20 conversation made
--                concrete - the keys are in the payload, not consumed by the export.
--
--   hierarchy    rootAwardNumber and parentAwardNumber travel with the award, so the
--                family structure survives the conversion whichever grain HRS picks
--                (D-17).
--
-- Field NAMES here are BU's, not Huron's. HRS has not told us its object model yet,
-- so this is the source document we can emit - reshaping the SELECT to whatever
-- HRS expects is a day's work, not a redesign. That is the point to make.
--
-- Nulls are emitted rather than dropped: an explicit null says "KC holds no value
-- here", which is different from a field that was never provided.
--
-- CHANGE THE AWARD NUMBER BELOW. Read-only.

WITH demo_award AS (
    SELECT '207805-00001' AS award_number FROM dual     -- <<<< change this
), selected_award AS (
    SELECT award_id, award_number, sequence_number, selection_rule
    FROM (
        SELECT a.award_id,
               a.award_number,
               a.sequence_number,
               CASE WHEN a.award_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY a.award_number
                   ORDER BY CASE WHEN a.award_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            a.sequence_number DESC,
                            a.award_id        DESC
               ) AS rn
        FROM   kcoeus.award a
        JOIN   demo_award   d ON d.award_number = a.award_number
    )
    WHERE rn = 1
), canonical_hierarchy AS (
    SELECT award_number, root_award_number, parent_award_number
    FROM (
        SELECT h.award_number, h.root_award_number, h.parent_award_number,
               ROW_NUMBER() OVER (
                   PARTITION BY h.award_number
                   ORDER BY CASE WHEN h.active = 'Y' THEN 0 ELSE 1 END,
                            h.update_timestamp   DESC,
                            h.award_hierarchy_id DESC) AS rn
        FROM   kcoeus.award_hierarchy h
    )
    WHERE rn = 1
)
SELECT JSON_OBJECT(
         /* ---- what ties this record back to KC after load (D-20) -------- */
         'sourceSystem'  VALUE 'KUALI_COEUS',
         'sourceObject'  VALUE 'AWARD',
         'sourceKeys'    VALUE JSON_OBJECT(
                                 'awardNumber'      VALUE a.award_number,
                                 'awardId'          VALUE a.award_id,
                                 'sequenceNumber'   VALUE a.sequence_number,
                                 'documentNumber'   VALUE a.document_number,
                                 'accountNumber'    VALUE a.account_number,
                                 'selectionRule'    VALUE s.selection_rule
                               ),
         /* ---- where this award sits in its family (D-17) ---------------- */
         'hierarchy'     VALUE JSON_OBJECT(
                                 'rootAwardNumber'   VALUE h.root_award_number,
                                 'parentAwardNumber' VALUE h.parent_award_number,
                                 'isRootAward'       VALUE CASE WHEN a.award_number = h.root_award_number
                                                                THEN 'Y' ELSE 'N' END
                               ),
         /* ---- the award itself ------------------------------------------ */
         'title'             VALUE a.title,
         'statusCode'        VALUE a.status_code,
         'statusDescription' VALUE ast.description,
         'awardTypeCode'     VALUE a.award_type_code,
         'awardTypeDescription' VALUE atyp.description,
         'sponsorCode'       VALUE a.sponsor_code,
         'sponsorName'       VALUE spn.sponsor_name,
         'leadUnitNumber'    VALUE a.lead_unit_number,
         'leadUnitName'      VALUE un.unit_name,
         'sponsorAwardNumber' VALUE a.sponsor_award_number,
         'beginDate'          VALUE TO_CHAR(a.begin_date, 'YYYY-MM-DD'),
         'awardEffectiveDate' VALUE TO_CHAR(a.award_effective_date, 'YYYY-MM-DD'),
         /* ---- BU's extension table -------------------------------------- */
         'buExtension'   VALUE JSON_OBJECT(
                                 'grantNumber'          VALUE ax.grant_number,
                                 'primeSponsorAwardId'  VALUE ax.prime_sponsor_award_id,
                                 'federalClinicalTrial' VALUE ax.federal_clinical_trial,
                                 'majorProject'         VALUE ax.major_project
                               ),
         /* ---- child collections, each an array, none multiplying --------- */
         'persons'       VALUE (SELECT JSON_ARRAYAGG(
                                         JSON_OBJECT(
                                           'awardPersonId' VALUE p.award_person_id,
                                           'personId'      VALUE p.person_id,
                                           'fullName'      VALUE p.full_name,
                                           'roleCode'      VALUE p.contact_role_code,
                                           'totalEffort'   VALUE p.total_effort
                                         ) RETURNING CLOB)
                                 FROM kcoeus.award_persons p
                                WHERE p.award_id = a.award_id),
         'amounts'       VALUE (SELECT JSON_ARRAYAGG(
                                         JSON_OBJECT(
                                           'awardAmountInfoId'   VALUE m.award_amount_info_id,
                                           'transactionId'       VALUE m.transaction_id,
                                           'anticipatedTotal'    VALUE m.anticipated_total_amount,
                                           'obligatedToDate'     VALUE m.amount_obligated_to_date,
                                           'finalExpirationDate' VALUE TO_CHAR(m.final_expiration_date,'YYYY-MM-DD')
                                         ) RETURNING CLOB)
                                 FROM kcoeus.award_amount_info m
                                WHERE m.award_id = a.award_id),
         'sponsorTerms'  VALUE (SELECT JSON_ARRAYAGG(
                                         JSON_OBJECT(
                                           'sponsorTermId'   VALUE st.sponsor_term_id,
                                           'sponsorTermCode' VALUE t.sponsor_term_code,
                                           'description'     VALUE t.description
                                         ) RETURNING CLOB)
                                 FROM kcoeus.award_sponsor_term st
                                 LEFT JOIN kcoeus.sponsor_term t ON t.sponsor_term_id = st.sponsor_term_id
                                WHERE st.award_id = a.award_id),
         'specialReviews' VALUE (SELECT JSON_ARRAYAGG(
                                         JSON_OBJECT(
                                           'specialReviewNumber' VALUE sr.special_review_number,
                                           'specialReviewCode'   VALUE sr.special_review_code,
                                           'protocolNumber'      VALUE sr.protocol_number,
                                           'approvalDate'        VALUE TO_CHAR(sr.approval_date,'YYYY-MM-DD')
                                         ) RETURNING CLOB)
                                 FROM kcoeus.award_special_review sr
                                WHERE sr.award_id = a.award_id),
         'customFields'  VALUE (SELECT JSON_ARRAYAGG(
                                         JSON_OBJECT(
                                           'customAttributeId' VALUE cd.custom_attribute_id,
                                           'name'              VALUE ca.name,
                                           'label'             VALUE ca.label,
                                           'groupName'         VALUE ca.group_name,
                                           'value'             VALUE cd.value
                                         ) RETURNING CLOB)
                                 FROM kcoeus.award_custom_data cd
                                 LEFT JOIN kcoeus.custom_attribute ca ON ca.id = cd.custom_attribute_id
                                WHERE cd.award_id = a.award_id)
         RETURNING CLOB
       ) AS award_document
FROM       selected_award       s
JOIN       kcoeus.award         a   ON a.award_id      = s.award_id
LEFT JOIN  canonical_hierarchy  h   ON h.award_number  = a.award_number
LEFT JOIN  kcoeus.award_extension ax ON ax.award_id    = a.award_id
LEFT JOIN  kcoeus.award_status  ast ON ast.status_code = TO_CHAR(a.status_code)
LEFT JOIN  kcoeus.award_type    atyp ON atyp.award_type_code = a.award_type_code
LEFT JOIN  kcoeus.sponsor       spn ON spn.sponsor_code = a.sponsor_code
LEFT JOIN  kcoeus.unit          un  ON un.unit_number   = a.lead_unit_number
