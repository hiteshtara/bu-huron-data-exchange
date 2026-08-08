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
       c.award_comment_id                  AS award_comment_id,
       c.award_id                          AS award_id,
       c.award_number                      AS award_number,
       c.sequence_number                   AS sequence_number,
       c.comment_type_code                 AS comment_type_code,
       ct.description                      AS comment_type_description,
       c.checklist_print_flag              AS checklist_print_flag,
       DBMS_LOB.SUBSTR(c.comments, 4000, 1) AS comments,
       c.ver_nbr                           AS version_number,
       c.update_timestamp                  AS update_timestamp,
       c.update_user                       AS update_user
FROM       kcoeus.award_comment c
LEFT JOIN  kcoeus.comment_type  ct ON ct.comment_type_code = c.comment_type_code
JOIN       huron_award_version v ON v.award_id = c.award_id

-- COMMENTS is a CLOB, truncated to 4000 chars so the dataset stays SQL-friendly.

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
