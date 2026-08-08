WITH huron_proposal_version AS (
    SELECT proposal_id, proposal_number, sequence_number, selection_rule
    FROM (
        SELECT p.proposal_id,
               p.proposal_number,
               p.sequence_number,
               CASE WHEN p.proposal_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY p.proposal_number
                   ORDER BY CASE WHEN p.proposal_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            p.sequence_number DESC,
                            p.proposal_id     DESC
               ) AS rn
        FROM   kcoeus.proposal p
    )
    WHERE rn = 1
)
SELECT
       uc.proposal_unit_contact_id         AS proposal_unit_contact_id,
       uc.proposal_id                      AS proposal_id,
       uc.proposal_number                  AS proposal_number,
       uc.sequence_number                  AS sequence_number,
       uc.person_id                        AS person_id,
       uc.full_name                        AS full_name,
       uc.unit_contact_type                AS unit_contact_type,
       uc.unit_administrator_type_code     AS unit_administrator_type_code,
       uat.description                     AS unit_administrator_type_description,
       uc.ver_nbr                          AS version_number,
       uc.update_timestamp                 AS update_timestamp,
       uc.update_user                      AS update_user
FROM       kcoeus.proposal_unit_contacts uc
JOIN       huron_proposal_version v ON v.proposal_id = uc.proposal_id
LEFT JOIN  kcoeus.unit_administrator_type uat
       ON  uat.unit_administrator_type_code = uc.unit_administrator_type_code

-- Contains person names: treat as PII when this dataset leaves BU.
