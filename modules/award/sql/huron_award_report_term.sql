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
       rt.award_report_terms_id            AS award_report_terms_id,
       rt.award_id                         AS award_id,
       rt.award_number                     AS award_number,
       rt.sequence_number                  AS sequence_number,
       rt.report_class_code                AS report_class_code,
       rc.description                      AS report_class_description,
       rt.report_code                      AS report_code,
       rp.description                      AS report_description,
       rt.frequency_code                   AS frequency_code,
       fr.description                      AS frequency_description,
       rt.frequency_base_code              AS frequency_base_code,
       fb.description                      AS frequency_base_description,
       rt.osp_distribution_code            AS osp_distribution_code,
       di.description                      AS osp_distribution_description,
       rt.due_date                         AS due_date,
       rt.ver_nbr                          AS version_number,
       rt.update_timestamp                 AS update_timestamp,
       rt.update_user                      AS update_user
FROM       kcoeus.award_report_terms rt
LEFT JOIN  kcoeus.report_class     rc ON rc.report_class_code    = rt.report_class_code
LEFT JOIN  kcoeus.report           rp ON rp.report_code          = rt.report_code
LEFT JOIN  kcoeus.frequency        fr ON fr.frequency_code       = rt.frequency_code
LEFT JOIN  kcoeus.frequency_base   fb ON fb.frequency_base_code  = rt.frequency_base_code
LEFT JOIN  kcoeus.distribution     di ON di.osp_distribution_code = rt.osp_distribution_code
JOIN       huron_award_version v ON v.award_id = rt.award_id

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
