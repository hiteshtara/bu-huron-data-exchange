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
       pu.award_person_unit_id             AS award_person_unit_id,
       pu.award_person_id                  AS award_person_id,
       p.award_id                          AS award_id,
       p.award_number                      AS award_number,
       p.sequence_number                   AS sequence_number,
       p.person_id                         AS person_id,
       pu.unit_number                      AS unit_number,
       u.unit_name                         AS unit_name,
       pu.lead_unit_flag                   AS lead_unit_flag,
       pu.ver_nbr                          AS version_number,
       pu.update_timestamp                 AS update_timestamp,
       pu.update_user                      AS update_user
FROM       kcoeus.award_person_units pu
JOIN       kcoeus.award_persons      p  ON p.award_person_id = pu.award_person_id
LEFT JOIN  kcoeus.unit               u  ON u.unit_number     = pu.unit_number
JOIN       huron_award_version v ON v.award_id = p.award_id

-- AWARD_PERSON_UNITS carries no award keys: it keys on AWARD_PERSON_ID. The join to
-- AWARD_PERSONS is many:1 and supplies award_id / award_number / sequence_number so
-- Huron can tie the row back to the correct award version.
-- Note the Java property is awardContactId but the column is AWARD_PERSON_ID.

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
