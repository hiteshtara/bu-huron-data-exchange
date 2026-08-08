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
       cs.proposal_per_credit_split_id     AS proposal_per_credit_split_id,
       cs.proposal_person_id               AS proposal_person_id,
       pp.proposal_id                      AS proposal_id,
       pp.proposal_number                  AS proposal_number,
       pp.sequence_number                  AS sequence_number,
       pp.person_id                        AS person_id,
       pp.full_name                        AS full_name,
       cs.inv_credit_type_code             AS inv_credit_type_code,
       ict.description                     AS inv_credit_type_description,
       cs.credit                           AS credit_percentage,
       cs.ver_nbr                          AS version_number,
       cs.update_timestamp                 AS update_timestamp,
       cs.update_user                      AS update_user
FROM       kcoeus.proposal_per_credit_split cs
JOIN       kcoeus.proposal_persons  pp  ON pp.proposal_person_id     = cs.proposal_person_id
JOIN       huron_proposal_version   v   ON v.proposal_id             = pp.proposal_id
LEFT JOIN  kcoeus.inv_credit_type   ict ON ict.inv_credit_type_code  = cs.inv_credit_type_code
