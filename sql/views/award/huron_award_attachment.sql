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
       at.award_attachment_id              AS award_attachment_id,
       at.award_id                         AS award_id,
       at.award_number                     AS award_number,
       at.sequence_number                  AS sequence_number,
       at.type_code                        AS attachment_type_code,
       att.description                     AS attachment_type_description,
       at.description                      AS attachment_description,
       at.document_id                      AS document_id,
       at.file_id                          AS file_id,
       at.document_status_code             AS document_status_code,
       at.ver_nbr                          AS version_number,
       at.update_timestamp                 AS update_timestamp,
       at.update_user                      AS update_user
FROM       kcoeus.award_attachment at
LEFT JOIN  kcoeus.award_attachment_type att ON att.type_code = at.type_code
JOIN       huron_award_version v ON v.award_id = at.award_id

-- Attachment METADATA only. The binary payload lives in ATTACHMENT_FILE/FILE_DATA
-- via FILE_ID and is deliberately not exposed -- file content is not mappable data.

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
