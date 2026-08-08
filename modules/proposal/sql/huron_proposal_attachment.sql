WITH huron_proposal_version AS (
    SELECT proposal_id, proposal_number, sequence_number, selection_rule
    FROM (
        SELECT p.proposal_id,
               p.proposal_number,
               p.sequence_number,
               CASE WHEN p.proposal_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY p.proposal_number
                   ORDER BY CASE WHEN p.proposal_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            p.sequence_number DESC,
                            p.proposal_id     DESC
               ) AS rn
        FROM   kcoeus.proposal p
    )
    WHERE rn = 1
)
SELECT
       at.proposal_attachments_id          AS proposal_attachments_id,
       at.proposal_id                      AS proposal_id,
       at.proposal_number                  AS proposal_number,
       at.sequence_number                  AS sequence_number,
       at.attachment_number                AS attachment_number,
       at.attachment_title                 AS attachment_title,
       at.attachment_type_code             AS attachment_type_code,
       att.description                     AS attachment_type_description,
       at.file_name                        AS file_name,
       at.content_type                     AS content_type,
       at.file_data_id                     AS file_data_id,
       at.document_status_code             AS document_status_code,
       DBMS_LOB.SUBSTR(at.comments, 2000, 1) AS comments,
       at.ver_nbr                          AS version_number,
       at.update_timestamp                 AS update_timestamp,
       at.update_user                      AS update_user
FROM       kcoeus.proposal_attachments at
JOIN       huron_proposal_version     v   ON v.proposal_id = at.proposal_id
LEFT JOIN  kcoeus.proposal_attachment_type att ON att.attachment_type_code = at.attachment_type_code

-- Attachment METADATA only. The binary payload lives in FILE_DATA via FILE_DATA_ID and
-- is deliberately not exposed -- file content is not mappable data.
