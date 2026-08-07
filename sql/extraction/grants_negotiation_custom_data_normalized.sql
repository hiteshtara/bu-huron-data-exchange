SELECT
    'Negotiation'              AS module,
    ncd.negotiation_number     AS record_number,
    ncd.negotiation_id         AS record_id,
    CAST(NULL AS NUMBER)       AS sequence_number,
    ncd.custom_attribute_id,
    ca.name                    AS custom_attribute_name,
    ca.label                   AS custom_attribute_label,
    ca.group_name,
    cadt.description           AS data_type,
    ca.data_length             AS max_length,
    ncd.value                  AS custom_value
FROM       negotiation_custom_data ncd
JOIN       custom_attribute ca       ON ca.id = ncd.custom_attribute_id
LEFT JOIN  custom_attribute_data_type cadt ON cadt.data_type_code = ca.data_type_code
ORDER BY   ncd.negotiation_number, ncd.custom_attribute_id
