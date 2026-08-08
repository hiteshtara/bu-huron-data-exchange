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
       cs.proposal_cost_sharing_id         AS proposal_cost_sharing_id,
       cs.proposal_id                      AS proposal_id,
       cs.proposal_number                  AS proposal_number,
       cs.sequence_number                  AS sequence_number,
       cs.project_period                   AS project_period,
       cs.cost_sharing_type_code           AS cost_sharing_type_code,
       cst.description                     AS cost_sharing_type_description,
       cs.amount                           AS amount,
       cs.cost_sharing_percentage          AS cost_sharing_percentage,
       cs.source_account                   AS source_account,
       cs.unit_number                      AS unit_number,
       un.unit_name                        AS unit_name,
       cs.ver_nbr                          AS version_number,
       cs.update_timestamp                 AS update_timestamp,
       cs.update_user                      AS update_user
FROM       kcoeus.proposal_cost_sharing cs
JOIN       huron_proposal_version v   ON v.proposal_id = cs.proposal_id
LEFT JOIN  kcoeus.cost_share_type cst ON cst.cost_share_type_code = cs.cost_sharing_type_code
LEFT JOIN  kcoeus.unit            un  ON un.unit_number           = cs.unit_number
