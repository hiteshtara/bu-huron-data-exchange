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
       co.award_closeout_id                AS award_closeout_id,
       co.award_id                         AS award_id,
       co.award_number                     AS award_number,
       co.sequence_number                  AS sequence_number,
       co.closeout_report_code             AS closeout_report_code,
       crt.description                     AS closeout_report_description,
       co.closeout_report_name             AS closeout_report_name,
       co.due_date                         AS due_date,
       co.final_submission_date            AS final_submission_date,
       co.multiple                         AS multiple_flag,
       co.ver_nbr                          AS version_number,
       co.update_timestamp                 AS update_timestamp,
       co.update_user                      AS update_user
FROM       kcoeus.award_closeout co
LEFT JOIN  kcoeus.closeout_report_type crt ON crt.closeout_report_code = co.closeout_report_code
JOIN       huron_award_version v ON v.award_id = co.award_id

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
