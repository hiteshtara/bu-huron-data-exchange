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
       h.award_hierarchy_id                AS award_hierarchy_id,
       h.award_number                      AS award_number,
       h.root_award_number                 AS root_award_number,
       h.parent_award_number               AS parent_award_number,
       h.originating_award_number          AS originating_award_number,
       h.active                            AS active_flag,
       h.ver_nbr                           AS version_number,
       h.update_timestamp                  AS update_timestamp,
       h.update_user                       AS update_user
FROM       kcoeus.award_hierarchy h
JOIN       huron_award_version v ON v.award_number = h.award_number

-- AWARD_HIERARCHY associates on AWARD_NUMBER, NOT AWARD_ID: the hierarchy describes
-- the award, not one of its versions. There is deliberately no SEQUENCE_NUMBER here.
-- Join to the Award root on AWARD_NUMBER alone.

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
