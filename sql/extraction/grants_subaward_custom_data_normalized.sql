SELECT
    'Subaward'                 AS module,
    scd.subaward_code          AS record_number,
    scd.subaward_id            AS record_id,
    scd.sequence_number,
    scd.custom_attribute_id,
    ca.name                    AS custom_attribute_name,
    ca.label                   AS custom_attribute_label,
    ca.group_name,
    cadt.description           AS data_type,
    ca.data_length             AS max_length,
    scd.value                  AS custom_value
FROM       subaward_custom_data scd
JOIN       custom_attribute ca       ON ca.id = scd.custom_attribute_id
LEFT JOIN  custom_attribute_data_type cadt ON cadt.data_type_code = ca.data_type_code
WHERE      MOD(scd.subaward_id, 93) = 0
ORDER BY   scd.subaward_code, scd.sequence_number, scd.custom_attribute_id
