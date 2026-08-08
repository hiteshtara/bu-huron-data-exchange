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
       ucs.ppu_credit_split_id             AS ppu_credit_split_id,
       ucs.proposal_person_unit_id         AS proposal_person_unit_id,
       pu.proposal_person_id               AS proposal_person_id,
       pp.proposal_id                      AS proposal_id,
       pp.proposal_number                  AS proposal_number,
       pp.sequence_number                  AS sequence_number,
       pp.person_id                        AS person_id,
       pu.unit_number                      AS unit_number,
       un.unit_name                        AS unit_name,
       ucs.inv_credit_type_code            AS inv_credit_type_code,
       ict.description                     AS inv_credit_type_description,
       ucs.credit                          AS credit_percentage,
       ucs.ver_nbr                         AS version_number,
       ucs.update_timestamp                AS update_timestamp,
       ucs.update_user                     AS update_user
FROM       kcoeus.proposal_pers_unit_cred_splits ucs
JOIN       kcoeus.proposal_person_units pu ON pu.proposal_person_unit_id = ucs.proposal_person_unit_id
JOIN       kcoeus.proposal_persons      pp ON pp.proposal_person_id      = pu.proposal_person_id
JOIN       huron_proposal_version       v  ON v.proposal_id              = pp.proposal_id
LEFT JOIN  kcoeus.unit                  un ON un.unit_number             = pu.unit_number
LEFT JOIN  kcoeus.inv_credit_type       ict ON ict.inv_credit_type_code  = ucs.inv_credit_type_code

-- Third level: proposal -> person -> person unit -> unit credit split.
