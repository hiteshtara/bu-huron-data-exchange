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
       s.award_approved_subaward_id        AS award_approved_subaward_id,
       s.award_id                          AS award_id,
       s.award_number                      AS award_number,
       s.sequence_number                   AS sequence_number,
       s.organization_id                   AS organization_id,
       o.organization_name                 AS organization_name_lookup,
       s.organization_name                 AS organization_name_entered,
       s.amount                            AS amount,
       s.ver_nbr                           AS version_number,
       s.update_timestamp                  AS update_timestamp,
       s.update_user                       AS update_user
FROM       kcoeus.award_approved_subawards s
LEFT JOIN  kcoeus.organization o ON o.organization_id = s.organization_id
JOIN       huron_award_version v ON v.award_id = s.award_id

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
