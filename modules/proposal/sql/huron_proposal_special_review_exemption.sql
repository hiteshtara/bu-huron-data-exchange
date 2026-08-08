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
       ex.proposal_exempt_number_id        AS proposal_exempt_number_id,
       ex.proposal_special_review_id       AS proposal_special_review_id,
       sr.proposal_id                      AS proposal_id,
       p.proposal_number                   AS proposal_number,
       p.sequence_number                   AS sequence_number,
       sr.protocol_number                  AS protocol_number,
       ex.exemption_type_code              AS exemption_type_code,
       et.description                      AS exemption_type_description,
       ex.ver_nbr                          AS version_number,
       ex.update_timestamp                 AS update_timestamp,
       ex.update_user                      AS update_user
FROM       kcoeus.proposal_exempt_number   ex
JOIN       kcoeus.proposal_special_review  sr ON sr.proposal_special_review_id = ex.proposal_special_review_id
JOIN       kcoeus.proposal                 p  ON p.proposal_id = sr.proposal_id
JOIN       huron_proposal_version          v  ON v.proposal_id = sr.proposal_id
LEFT JOIN  kcoeus.exemption_type           et ON et.exemption_type_code = ex.exemption_type_code
