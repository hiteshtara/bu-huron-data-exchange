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
       cf.proposal_cfda_id                 AS proposal_cfda_id,
       cf.proposal_id                      AS proposal_id,
       cf.proposal_number                  AS proposal_number,
       cf.sequence_number                  AS sequence_number,
       cf.cfda_number                      AS cfda_number,
       cf.cfda_description                 AS cfda_description,
       cf.ver_nbr                          AS version_number,
       cf.update_timestamp                 AS update_timestamp,
       cf.update_user                      AS update_user
FROM       kcoeus.proposal_cfda cf
JOIN       huron_proposal_version v ON v.proposal_id = cf.proposal_id
