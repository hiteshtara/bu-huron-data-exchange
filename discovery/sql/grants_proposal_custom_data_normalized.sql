WITH sampled_proposals AS (
    SELECT proposal_id
    FROM   proposal
    WHERE  MOD(proposal_id, 130) = 0
)
SELECT
    'Institutional Proposal'   AS module,
    pcd.proposal_number        AS record_number,
    pcd.proposal_id            AS record_id,
    pcd.sequence_number,
    pcd.custom_attribute_id,
    ca.name                    AS custom_attribute_name,
    ca.label                   AS custom_attribute_label,
    ca.group_name,
    cadt.description           AS data_type,
    ca.data_length             AS max_length,
    pcd.value                  AS custom_value
FROM       proposal_custom_data pcd
JOIN       sampled_proposals s       ON s.proposal_id = pcd.proposal_id
JOIN       custom_attribute ca       ON ca.id = pcd.custom_attribute_id
LEFT JOIN  custom_attribute_data_type cadt ON cadt.data_type_code = ca.data_type_code
ORDER BY   pcd.proposal_number, pcd.sequence_number, pcd.custom_attribute_id
