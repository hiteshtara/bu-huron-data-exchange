WITH huron_subaward_version AS (
    SELECT subaward_id, subaward_code, sequence_number, selection_rule
    FROM (
        SELECT s.subaward_id,
               s.subaward_code,
               s.sequence_number,
               CASE WHEN s.subaward_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY s.subaward_code
                   ORDER BY CASE WHEN s.subaward_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            s.sequence_number  DESC,
                            s.update_timestamp DESC,
                            s.subaward_id      DESC
               ) AS rn
        FROM   kcoeus.subaward s
    )
    WHERE rn = 1
)
SELECT
       r.subaward_report_id                AS subaward_report_id,
       r.subaward_id                       AS subaward_id,
       r.subaward_code                     AS subaward_code,
       r.sequence_number                   AS sequence_number,
       r.report_type_code                  AS report_type_code,
       rt.description                      AS report_type_description,
       r.ver_nbr                           AS version_number,
       r.update_timestamp                  AS update_timestamp,
       r.update_user                       AS update_user
FROM       kcoeus.subaward_reports r
JOIN       huron_subaward_version v ON v.subaward_id = r.subaward_id
LEFT JOIN  kcoeus.subaward_report_type rt ON rt.report_type_code = r.report_type_code
