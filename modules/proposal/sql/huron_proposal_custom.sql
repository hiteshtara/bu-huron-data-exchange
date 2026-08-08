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
       cd.proposal_custom_data_id          AS proposal_custom_data_id,
       cd.proposal_id                      AS proposal_id,
       cd.proposal_number                  AS proposal_number,
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
FROM       kcoeus.proposal_custom_data cd
JOIN       huron_proposal_version v ON v.proposal_id = cd.proposal_id
LEFT JOIN  kcoeus.custom_attribute ca  ON ca.id = cd.custom_attribute_id
LEFT JOIN  kcoeus.custom_attribute_data_type cadt ON cadt.data_type_code = ca.data_type_code
LEFT JOIN  kcoeus.custom_attribute_document cad
       ON  cad.custom_attribute_id = ca.id
       AND cad.document_type_code  = 'INPR'

-- BU custom fields are EAV. The logical field is CUSTOM_ATTRIBUTE_ID plus its
-- definition, NOT the physical VALUE column. VALUE is exposed as CUSTOM_VALUE and
-- always accompanied by the attribute name, label, group and datatype.
--
-- CUSTOM_ATTRIBUTE_DOCUMENT is filtered to 'INPR' INSIDE the join: an attribute can be
-- attached to several document types, so an unfiltered join would multiply rows.
-- Module applicability comes from that configuration, never from the presence of a
-- value. Where APPLIES_TO_DOCUMENT_TYPE is NULL the attribute has proposal values but
-- is not configured for INPR -- attributes 1212 "Contract" and 1213 "Billing
-- Agreement". Those values ARE exposed -- they exist, and a configuration mismatch is
-- not grounds for silently discarding data. The NULL marks the mismatch for review.
