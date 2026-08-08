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
       co.subaward_closeout_id             AS subaward_closeout_id,
       co.subaward_id                      AS subaward_id,
       co.subaward_code                    AS subaward_code,
       co.sequence_number                  AS sequence_number,
       co.closeout_number                  AS closeout_number,
       co.closeout_type_code               AS closeout_type_code,
       cot.description                     AS closeout_type_description,
       co.date_requested                   AS date_requested,
       co.date_followup                    AS date_followup,
       co.date_received                    AS date_received,
       DBMS_LOB.SUBSTR(co.comments, 2000, 1) AS comments,
       co.ver_nbr                          AS version_number,
       co.update_timestamp                 AS update_timestamp,
       co.update_user                      AS update_user
FROM       kcoeus.subaward_closeout co
JOIN       huron_subaward_version v ON v.subaward_id = co.subaward_id
LEFT JOIN  kcoeus.closeout_type cot ON cot.closeout_type_code = co.closeout_type_code
