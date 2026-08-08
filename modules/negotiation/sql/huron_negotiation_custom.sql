SELECT
       cd.negotiation_custom_data_id       AS negotiation_custom_data_id,
       cd.negotiation_id                   AS negotiation_id,
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
FROM       kcoeus.negotiation_custom_data cd
LEFT JOIN  kcoeus.custom_attribute ca ON ca.id = cd.custom_attribute_id
LEFT JOIN  kcoeus.custom_attribute_data_type cadt ON cadt.data_type_code = ca.data_type_code
LEFT JOIN  kcoeus.custom_attribute_document cad
       ON  cad.custom_attribute_id = ca.id
       AND cad.document_type_code  = 'NGT'

-- BU custom fields. VALUE alone is meaningless, so the attribute definition comes with
-- it. CUSTOM_ATTRIBUTE_DOCUMENT is filtered to 'NGT' inside the join, because an
-- attribute can be attached to several document types and an unfiltered join would
-- multiply rows.
--
-- 8 attributes configured for NGT, the same 8 in use, nothing populated that is not
-- attached, and no row pointing at a missing definition. Two of the 8 have rows but no
-- non-NULL value anywhere.
--
-- Note NEGOTIATION_CUSTOM_DATA has a NEGOTIATION_NUMBER column that is NULL on all
-- 94,736 rows. It is a dead column -- join on NEGOTIATION_ID.
