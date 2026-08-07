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
       uc.award_unit_contact_id            AS award_unit_contact_id,
       uc.award_id                         AS award_id,
       uc.award_number                     AS award_number,
       uc.sequence_number                  AS sequence_number,
       uc.person_id                        AS person_id,
       uc.full_name                        AS full_name,
       uc.unit_contact_type                AS unit_contact_type,
       uc.unit_administrator_type_code     AS unit_administrator_type_code,
       uat.description                     AS unit_administrator_type_description,
       uc.unit_administrator_unit_number   AS unit_administrator_unit_number,
       un.unit_name                        AS unit_administrator_unit_name,
       uc.default_unit_contact             AS default_unit_contact,
       uc.ver_nbr                          AS version_number,
       uc.update_timestamp                 AS update_timestamp,
       uc.update_user                      AS update_user
FROM       kcoeus.award_unit_contacts uc
LEFT JOIN  kcoeus.unit_administrator_type uat
       ON  uat.unit_administrator_type_code = uc.unit_administrator_type_code
LEFT JOIN  kcoeus.unit un ON un.unit_number = uc.unit_administrator_unit_number
JOIN       huron_award_version v ON v.award_id = uc.award_id

-- Contains person names: treat as PII when this dataset leaves BU.

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
