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
       r.award_idc_rate_id                 AS award_idc_rate_id,
       r.award_id                          AS award_id,
       r.award_number                      AS award_number,
       r.sequence_number                   AS sequence_number,
       r.idc_rate_type_code                AS idc_rate_type_code,
       irt.description                     AS idc_rate_type_description,
       r.applicable_idc_rate               AS applicable_idc_rate,
       r.underrecovery_of_idc              AS underrecovery_of_idc,
       r.fiscal_year                       AS fiscal_year,
       r.on_campus_flag                    AS on_campus_flag,
       r.start_date                        AS start_date,
       r.end_date                          AS end_date,
       r.source_account                    AS source_account,
       r.destination_account               AS destination_account,
       r.ver_nbr                           AS version_number,
       r.update_timestamp                  AS update_timestamp,
       r.update_user                       AS update_user
FROM       kcoeus.award_idc_rate r
LEFT JOIN  kcoeus.idc_rate_type  irt ON irt.idc_rate_type_code = r.idc_rate_type_code
JOIN       huron_award_version v ON v.award_id = r.award_id

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
