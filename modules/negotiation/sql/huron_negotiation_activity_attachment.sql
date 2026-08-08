SELECT
       at.attachment_id                    AS negotiation_attachment_id,
       at.activity_id                      AS negotiation_activity_id,
       a.negotiation_id                    AS negotiation_id,
       at.file_id                          AS file_id,
       at.description                      AS description,
       at.restricted                       AS restricted_flag,
       at.ver_nbr                          AS version_number,
       at.update_timestamp                 AS update_timestamp,
       at.update_user                      AS update_user
FROM       kcoeus.negotiation_attachment at
JOIN       kcoeus.negotiation_activity    a ON a.negotiation_activity_id = at.activity_id

-- Attachments hang off an ACTIVITY, not off the negotiation, so we join back through
-- NEGOTIATION_ACTIVITY to give each row its NEGOTIATION_ID. Metadata only -- the file
-- itself lives in ATTACHMENT_FILE via FILE_ID.
