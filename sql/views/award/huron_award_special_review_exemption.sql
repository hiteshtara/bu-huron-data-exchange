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
       ex.award_exempt_number_id           AS award_exempt_number_id,
       ex.award_special_review_id          AS award_special_review_id,
       sr.award_id                         AS award_id,
       a.award_number                      AS award_number,
       a.sequence_number                   AS sequence_number,
       sr.protocol_number                  AS protocol_number,
       ex.exemption_type_code              AS exemption_type_code,
       ex.ver_nbr                          AS version_number,
       ex.update_timestamp                 AS update_timestamp,
       ex.update_user                      AS update_user
FROM       kcoeus.award_exempt_number  ex
JOIN       kcoeus.award_special_review sr ON sr.award_special_review_id = ex.award_special_review_id
JOIN       kcoeus.award                a  ON a.award_id                 = sr.award_id
JOIN       huron_award_version v ON v.award_id = sr.award_id

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
