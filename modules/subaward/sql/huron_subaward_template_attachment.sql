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
       ta.attachment_id                    AS attachment_id,
       ta.subaward_id                      AS subaward_id,
       ta.subaward_code                    AS subaward_code,
       ta.sequence_number                  AS sequence_number,
       ta.attachment_type_code             AS attachment_type_code,
       tat.description                     AS attachment_type_description,
       ta.description                      AS attachment_description,
       ta.file_name                        AS file_name,
       ta.mime_type                        AS mime_type,
       ta.file_data_id                     AS file_data_id,
       ta.document_status_code             AS document_status_code,
       ta.ver_nbr                          AS version_number,
       ta.update_timestamp                 AS update_timestamp,
       ta.update_user                      AS update_user
FROM       kcoeus.subaward_template_attachments ta
JOIN       huron_subaward_version v ON v.subaward_id = ta.subaward_id
LEFT JOIN  kcoeus.subaward_tmpl_attach_type tat ON tat.attachment_type_code = ta.attachment_type_code
