SELECT
       n.negotiation_id                    AS negotiation_id,
       n.document_number                   AS document_number,
       n.ver_nbr                           AS version_number,
       /* ---- what this negotiation is about ----------------------------- */
       n.negotiation_assc_type_id          AS association_type_id,
       at.description                      AS association_type,
       n.associated_document_id            AS associated_document_id,
       CASE at.description
            WHEN 'Award'                  THEN 'AWARD.AWARD_NUMBER'
            WHEN 'Subaward'               THEN 'SUBAWARD.SUBAWARD_CODE'
            WHEN 'Institutional Proposal' THEN 'PROPOSAL.PROPOSAL_NUMBER'
            WHEN 'None'                   THEN 'NEGOTIATION_UNASSOC_DETAIL'
            ELSE NULL END                  AS associated_document_id_means,
       /* ---- status and type -------------------------------------------- */
       n.negotation_status_id              AS negotiation_status_id,
       st.description                      AS negotiation_status,
       n.negotiation_agreement_type_id     AS agreement_type_id,
       ag.description                      AS agreement_type,
       /* ---- who and when ----------------------------------------------- */
       n.negotiator_person_id              AS negotiator_person_id,
       n.negotiator_full_name              AS negotiator_full_name,
       n.negotiation_start_date            AS negotiation_start_date,
       n.negotiation_end_date              AS negotiation_end_date,
       n.anticipated_award_date            AS anticipated_award_date,
       n.document_folder                   AS document_folder,
       /* ---- details for negotiations not tied to an existing record ----- */
       ud.title                            AS unassociated_title,
       ud.pi_person_id                     AS unassociated_pi_person_id,
       ud.pi_name                          AS unassociated_pi_name,
       ud.pi_rolodex_id                    AS unassociated_pi_rolodex_id,
       ud.lead_unit                        AS unassociated_lead_unit_number,
       un.unit_name                        AS unassociated_lead_unit_name,
       ud.sponsor_code                     AS unassociated_sponsor_code,
       spn.sponsor_name                    AS unassociated_sponsor_name,
       ud.prime_sponsor_code               AS unassociated_prime_sponsor_code,
       psp.sponsor_name                    AS unassociated_prime_sponsor_name,
       ud.sponsor_award_number             AS unassociated_sponsor_award_number,
       ud.subaward_org                     AS unassociated_subaward_organization_id,
       org.organization_name               AS unassociated_subaward_organization_name,
       ud.contact_admin_person_id          AS unassociated_contact_admin_person_id,
       n.update_timestamp                  AS update_timestamp,
       n.update_user                       AS update_user
FROM       kcoeus.negotiation n
LEFT JOIN  kcoeus.negotiation_status           st ON st.negotiation_status_id = n.negotation_status_id
LEFT JOIN  kcoeus.negotiation_agreement_type   ag ON ag.negotiation_agrmnt_type_id = n.negotiation_agreement_type_id
LEFT JOIN  kcoeus.negotiation_association_type at ON at.negotiation_assc_type_id = n.negotiation_assc_type_id
LEFT JOIN  kcoeus.negotiation_unassoc_detail   ud ON ud.negotiation_id = n.negotiation_id
LEFT JOIN  kcoeus.unit         un  ON un.unit_number     = ud.lead_unit
LEFT JOIN  kcoeus.sponsor      spn ON spn.sponsor_code   = ud.sponsor_code
LEFT JOIN  kcoeus.sponsor      psp ON psp.sponsor_code   = ud.prime_sponsor_code
LEFT JOIN  kcoeus.organization org ON org.organization_id = ud.subaward_org

-- HURON_NEGOTIATION -- one row per negotiation. No version selector, because
-- Negotiation is not versioned: 11,842 rows, 11,842 distinct ids, and nothing in
-- VERSION_HISTORY. See huron_negotiation_population_validation.sql.
--
-- ASSOCIATED_DOCUMENT_ID is a polymorphic key: what it points at depends on the
-- association type, so we spell that out in ASSOCIATED_DOCUMENT_ID_MEANS rather than
-- leaving it for someone to work out. Every row resolves against the right parent:
--
--     Award                  2,574 -> AWARD.AWARD_NUMBER       (2,574 matched)
--     Subaward                  16 -> SUBAWARD.SUBAWARD_CODE      (16 matched)
--     Institutional Proposal     3 -> PROPOSAL.PROPOSAL_NUMBER      (3 matched)
--     None                   9,249 -> no parent; the detail is in
--                                     NEGOTIATION_UNASSOC_DETAIL (9,249 matched)
--
-- Most negotiations at BU (78%) are not attached to an existing record. For those, the
-- title, PI, unit and sponsor live in NEGOTIATION_UNASSOC_DETAIL, which is 1:1 on
-- NEGOTIATION_ID, so we folded it into the root instead of making it a child dataset.
-- Those columns are NULL for the associated negotiations, which is expected.
