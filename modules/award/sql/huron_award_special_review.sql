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
       sr.award_special_review_id          AS award_special_review_id,
       sr.award_id                         AS award_id,
       a.award_number                      AS award_number,
       a.sequence_number                   AS sequence_number,
       sr.special_review_number            AS special_review_number,
       sr.special_review_code              AS special_review_code,
       srt.description                     AS special_review_description,
       sr.approval_type_code               AS approval_type_code,
       apt.description                     AS approval_type_description,
       sr.protocol_number                  AS protocol_number,
       sr.application_date                 AS application_date,
       sr.approval_date                    AS approval_date,
       sr.expiration_date                  AS expiration_date,
       sr.comments                         AS comments,
       sr.ver_nbr                          AS version_number,
       sr.update_timestamp                 AS update_timestamp,
       sr.update_user                      AS update_user
FROM       kcoeus.award_special_review sr
JOIN       kcoeus.award                 a   ON a.award_id = sr.award_id
LEFT JOIN  kcoeus.special_review        srt ON srt.special_review_code = sr.special_review_code
LEFT JOIN  kcoeus.sp_rev_approval_type  apt ON apt.approval_type_code  = sr.approval_type_code
JOIN       huron_award_version v ON v.award_id = sr.award_id

-- AWARD_SPECIAL_REVIEW carries only AWARD_ID; AWARD is joined many:1 for the
-- business keys. PROTOCOL_NUMBER is the lineage link to the IRB/IACUC module.

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
