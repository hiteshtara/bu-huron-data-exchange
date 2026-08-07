WITH sampled_awards AS (
    SELECT award_id
    FROM   award
    WHERE  MOD(award_id, 283) = 0
)
SELECT
    'Award'                    AS module,
    acd.award_number           AS record_number,
    acd.award_id               AS record_id,
    acd.sequence_number,
    acd.custom_attribute_id,
    ca.name                    AS custom_attribute_name,
    ca.label                   AS custom_attribute_label,
    ca.group_name,
    cadt.description           AS data_type,
    ca.data_length             AS max_length,
    acd.value                  AS custom_value
FROM       award_custom_data acd
JOIN       sampled_awards s          ON s.award_id = acd.award_id
JOIN       custom_attribute ca       ON ca.id = acd.custom_attribute_id
LEFT JOIN  custom_attribute_data_type cadt ON cadt.data_type_code = ca.data_type_code
ORDER BY   acd.award_number, acd.sequence_number, acd.custom_attribute_id
