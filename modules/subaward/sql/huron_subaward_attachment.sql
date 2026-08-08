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
       at.attachment_id                    AS attachment_id,
       at.subaward_id                      AS subaward_id,
       at.subaward_code                    AS subaward_code,
       at.sequence_number                  AS sequence_number,
       at.attachment_type_code             AS attachment_type_code,
       att.description                     AS attachment_type_description,
       at.description                      AS attachment_description,
       at.file_name                        AS file_name,
       at.mime_type                        AS mime_type,
       at.file_data_id                     AS file_data_id,
       at.document_id                      AS document_id,
       at.document_status_code             AS document_status_code,
       at.ver_nbr                          AS version_number,
       at.update_timestamp                 AS update_timestamp,
       at.update_user                      AS update_user
FROM       kcoeus.subaward_attachments at
JOIN       huron_subaward_version v ON v.subaward_id = at.subaward_id
LEFT JOIN  kcoeus.subaward_attachment_type att ON att.attachment_type_code = at.attachment_type_code

-- Attachment metadata only. The file itself lives in FILE_DATA via FILE_DATA_ID and is
-- not exposed -- file content is not something Huron can map.
