-- DEMO 6 - BU's custom fields, resolved from the EAV model to real labels.
--
-- KC stores institution-specific fields entity-attribute-value: CUSTOM_ATTRIBUTE
-- holds the definitions, AWARD_CUSTOM_DATA holds the values, joined on
-- CUSTOM_ATTRIBUTE_ID. Read AWARD_CUSTOM_DATA on its own and you get numbers
-- against numbers. This query turns it back into BU's field names.
--
-- Good one to run live because the raw table is genuinely unreadable and the
-- resolved version is immediately obvious - it makes the point about why the
-- schema alone is not enough.
--
-- Scoped to Award ('AWRD'). Swap the document type code for the other modules:
--   AWRD = Award   INPR = Institutional Proposal   SAWD = Subaward   NGT = Negotiation
--
-- Read-only.

SELECT ca.id                                     AS custom_attribute_id,
       ca.label                                  AS bu_field_label,
       ca.group_name                             AS group_name,
       cadt.description                          AS data_type,
       cad.is_required                           AS is_required,
       COUNT(cd.award_custom_data_id)            AS value_rows,
       COUNT(TRIM(cd.value))                     AS populated_values,
       COUNT(DISTINCT TRIM(cd.value))            AS distinct_values
FROM       kcoeus.custom_attribute           ca
JOIN       kcoeus.custom_attribute_document  cad
       ON  cad.custom_attribute_id = ca.id
       AND cad.document_type_code  = 'AWRD'
LEFT JOIN  kcoeus.custom_attribute_data_type cadt
       ON  cadt.data_type_code = ca.data_type_code
LEFT JOIN  kcoeus.award_custom_data          cd
       ON  cd.custom_attribute_id = ca.id
GROUP  BY  ca.id, ca.label, ca.group_name, cadt.description, cad.is_required
ORDER  BY  populated_values DESC, ca.label
