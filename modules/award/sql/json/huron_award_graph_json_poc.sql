SELECT JSON_OBJECT(
         'awardId'         VALUE a.award_id,
         'awardNumber'     VALUE a.award_number,
         'sequenceNumber'  VALUE a.sequence_number,
         'title'           VALUE a.title,
         'statusCode'      VALUE a.status_code,
         'statusDescription' VALUE ast.description,
         'sponsorCode'     VALUE a.sponsor_code,
         'sponsorName'     VALUE spn.sponsor_name,
         'leadUnitNumber'  VALUE a.lead_unit_number,
         'leadUnitName'    VALUE un.unit_name,
         'buExtension'     VALUE JSON_OBJECT(
                                   'grantNumber'          VALUE ax.grant_number,
                                   'primeSponsorAwardId'  VALUE ax.prime_sponsor_award_id,
                                   'federalClinicalTrial' VALUE ax.federal_clinical_trial,
                                   'majorProject'         VALUE ax.major_project
                                 ),
         'persons'         VALUE (SELECT JSON_ARRAYAGG(
                                           JSON_OBJECT(
                                             'awardPersonId' VALUE p.award_person_id,
                                             'personId'      VALUE p.person_id,
                                             'fullName'      VALUE p.full_name,
                                             'roleCode'      VALUE p.contact_role_code,
                                             'totalEffort'   VALUE p.total_effort
                                           ) RETURNING CLOB)
                                   FROM award_persons p
                                  WHERE p.award_id = a.award_id),
         'amounts'         VALUE (SELECT JSON_ARRAYAGG(
                                           JSON_OBJECT(
                                             'awardAmountInfoId'    VALUE m.award_amount_info_id,
                                             'transactionId'        VALUE m.transaction_id,
                                             'anticipatedTotal'     VALUE m.anticipated_total_amount,
                                             'obligatedToDate'      VALUE m.amount_obligated_to_date,
                                             'finalExpirationDate'  VALUE TO_CHAR(m.final_expiration_date,'YYYY-MM-DD')
                                           ) RETURNING CLOB)
                                   FROM award_amount_info m
                                  WHERE m.award_id = a.award_id),
         'sponsorTerms'    VALUE (SELECT JSON_ARRAYAGG(
                                           JSON_OBJECT(
                                             'sponsorTermId'   VALUE st.sponsor_term_id,
                                             'sponsorTermCode' VALUE t.sponsor_term_code,
                                             'description'     VALUE t.description
                                           ) RETURNING CLOB)
                                   FROM award_sponsor_term st
                                   LEFT JOIN sponsor_term t ON t.sponsor_term_id = st.sponsor_term_id
                                  WHERE st.award_id = a.award_id),
         'specialReviews'  VALUE (SELECT JSON_ARRAYAGG(
                                           JSON_OBJECT(
                                             'specialReviewNumber' VALUE sr.special_review_number,
                                             'specialReviewCode'   VALUE sr.special_review_code,
                                             'protocolNumber'      VALUE sr.protocol_number,
                                             'approvalDate'        VALUE TO_CHAR(sr.approval_date,'YYYY-MM-DD')
                                           ) RETURNING CLOB)
                                   FROM award_special_review sr
                                  WHERE sr.award_id = a.award_id),
         'customFields'    VALUE (SELECT JSON_ARRAYAGG(
                                           JSON_OBJECT(
                                             'customAttributeId' VALUE cd.custom_attribute_id,
                                             'name'              VALUE ca.name,
                                             'label'             VALUE ca.label,
                                             'groupName'         VALUE ca.group_name,
                                             'value'             VALUE cd.value
                                           ) RETURNING CLOB)
                                   FROM award_custom_data cd
                                   LEFT JOIN custom_attribute ca ON ca.id = cd.custom_attribute_id
                                  WHERE cd.award_id = a.award_id)
         RETURNING CLOB
       ) AS award_graph_json
FROM       kcoeus.award a
LEFT JOIN  kcoeus.award_extension ax  ON ax.award_id     = a.award_id
LEFT JOIN  kcoeus.award_status    ast ON ast.status_code = TO_CHAR(a.status_code)
LEFT JOIN  kcoeus.sponsor         spn ON spn.sponsor_code = a.sponsor_code
LEFT JOIN  kcoeus.unit            un  ON un.unit_number   = a.lead_unit_number
WHERE      a.award_id = 1092870

-- PROOF OF CONCEPT -- ONE award only, deliberately pinned by award_id.
-- Not the primary interface. Demonstrates that the whole Award graph can be
-- returned as a single nested document with NO Cartesian multiplication:
-- each collection is a correlated scalar subquery feeding JSON_ARRAYAGG, so
-- persons x terms x customFields never cross-multiply.
-- Verified on Oracle Database 19c Standard Edition 2 (JSON_OBJECT / JSON_ARRAYAGG
-- both available). RETURNING CLOB is required -- the default VARCHAR2(4000) return
-- overflows on real awards.
