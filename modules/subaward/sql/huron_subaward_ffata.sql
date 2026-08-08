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
       ff.subaward_ffata_reporting_id      AS subaward_ffata_reporting_id,
       ff.subaward_id                      AS subaward_id,
       v.subaward_code                     AS subaward_code,
       v.sequence_number                   AS sequence_number,
       ff.subaward_amount_info_id          AS subaward_amount_info_id,
       ff.date_submitted                   AS date_submitted,
       ff.submitter_id                     AS submitter_person_id,
       ff.other_trans_desc                 AS other_transaction_description,
       ff.file_name                        AS file_name,
       ff.mime_type                        AS mime_type,
       ff.file_data_id                     AS file_data_id,
       DBMS_LOB.SUBSTR(ff.comments, 2000, 1) AS comments,
       ff.ver_nbr                          AS version_number,
       ff.update_timestamp                 AS update_timestamp,
       ff.update_user                      AS update_user
FROM       kcoeus.subaward_ffata_reporting ff
JOIN       huron_subaward_version v ON v.subaward_id = ff.subaward_id

-- FFATA reporting ties back to a specific money row through SUBAWARD_AMOUNT_INFO_ID,
-- so it can be joined to huron_subaward_amount as well as to the subaward root.
