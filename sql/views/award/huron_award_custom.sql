WITH huron_award_version AS (
    SELECT award_id, award_number, sequence_number, selection_rule
    FROM (
        SELECT a.award_id,
               a.award_number,
               a.sequence_number,
               CASE WHEN a.award_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY a.award_number
                   ORDER BY CASE WHEN a.award_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            a.sequence_number DESC,
                            a.award_id        DESC
               ) AS rn
        FROM   kcoeus.award a
    )
    WHERE rn = 1
)
SELECT
       cd.award_custom_data_id             AS award_custom_data_id,
       cd.award_id                         AS award_id,
       cd.award_number                     AS award_number,
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
FROM       kcoeus.award_custom_data cd
LEFT JOIN  kcoeus.custom_attribute  ca   ON ca.id = cd.custom_attribute_id
LEFT JOIN  kcoeus.custom_attribute_data_type cadt ON cadt.data_type_code = ca.data_type_code
LEFT JOIN  kcoeus.custom_attribute_document  cad
       ON  cad.custom_attribute_id = ca.id
       AND cad.document_type_code  = 'AWRD'
JOIN       huron_award_version v ON v.award_id = cd.award_id

-- BU custom fields are EAV. The logical field is CUSTOM_ATTRIBUTE_ID plus its
-- definition -- NOT the physical VALUE column, which is only generic storage.
-- VALUE is therefore exposed as CUSTOM_VALUE and always accompanied by
-- CUSTOM_ATTRIBUTE_NAME / CUSTOM_ATTRIBUTE_LABEL / GROUP_NAME / DATA_TYPE.
--
-- CUSTOM_ATTRIBUTE_DOCUMENT is filtered to document_type_code = 'AWRD' inside the
-- join. An attribute may be attached to several document types, so an unfiltered
-- join would multiply rows. Module applicability comes from this configuration
-- table, never from the presence of a value: where APPLIES_TO_DOCUMENT_TYPE is
-- NULL the attribute has award values but is not configured for Award (e.g.
-- attribute 1212 "Contract"). Reported, not resolved.
--
-- CUSTOM_ATTRIBUTE is LEFT JOINed on purpose. Two AWARD_CUSTOM_DATA rows reference
-- custom_attribute_id 720 and 730, which no longer exist in CUSTOM_ATTRIBUTE. An
-- inner join would silently discard them; this way they surface with a NULL definition
-- and stay visible as the anomaly they are. Reported, not resolved.

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
