WITH huron_subaward_version AS (
    SELECT subaward_id, subaward_code, sequence_number, selection_rule
    FROM (
        SELECT s.subaward_id,
               s.subaward_code,
               s.sequence_number,
               CASE WHEN s.subaward_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY s.subaward_code
                   ORDER BY CASE WHEN s.subaward_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            s.sequence_number  DESC,
                            s.update_timestamp DESC,
                            s.subaward_id      DESC
               ) AS rn
        FROM   kcoeus.subaward s
    )
    WHERE rn = 1
)
SELECT
       cd.subaward_custom_data_id          AS subaward_custom_data_id,
       cd.subaward_id                      AS subaward_id,
       cd.subaward_code                    AS subaward_code,
       cd.sequence_number                  AS sequence_number,
       cd.custom_attribute_id              AS custom_attribute_id,
       ca.name                             AS custom_attribute_name,
       ca.label                            AS custom_attribute_label,
       ca.group_name                       AS group_name,
       cadt.description                    AS data_type,
       ca.data_length                      AS max_length,
       ca.default_value                    AS default_value,
       cad.document_type_code              AS applies_to_document_type,
       cad.is_required                     AS is_required,
       cad.active_flag                     AS attribute_active_flag,
       cd.value                            AS custom_value,
       cd.ver_nbr                          AS version_number,
       cd.update_timestamp                 AS update_timestamp,
       cd.update_user                      AS update_user
FROM       kcoeus.subaward_custom_data cd
JOIN       huron_subaward_version v ON v.subaward_id = cd.subaward_id
LEFT JOIN  kcoeus.custom_attribute ca ON ca.id = cd.custom_attribute_id
LEFT JOIN  kcoeus.custom_attribute_data_type cadt ON cadt.data_type_code = ca.data_type_code
LEFT JOIN  kcoeus.custom_attribute_document cad
       ON  cad.custom_attribute_id = ca.id
       AND cad.document_type_code  = 'SAWD'

-- BU custom fields. VALUE on its own means nothing -- the field is whatever
-- CUSTOM_ATTRIBUTE_ID is defined to be -- so we join the definition and expose the
-- name, label, group and datatype alongside the value.
--
-- We filter CUSTOM_ATTRIBUTE_DOCUMENT to 'SAWD' inside the join. An attribute can be
-- attached to more than one document type, and an unfiltered join would multiply rows.
--
-- Subaward is the cleanest of the three modules here: 15 attributes configured, the
-- same 15 in use, nothing populated that is not attached to SAWD, and no rows pointing
-- at a missing definition. One attribute has rows but no non-NULL value.
