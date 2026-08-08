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
       cs.award_person_credit_split_id     AS award_person_credit_split_id,
       cs.award_person_id                  AS award_person_id,
       p.award_id                          AS award_id,
       p.award_number                      AS award_number,
       p.sequence_number                   AS sequence_number,
       p.person_id                         AS person_id,
       p.full_name                         AS full_name,
       cs.inv_credit_type_code             AS inv_credit_type_code,
       ict.description                     AS inv_credit_type_description,
       cs.credit                           AS credit_percentage,
       cs.ver_nbr                          AS version_number,
       cs.update_timestamp                 AS update_timestamp,
       cs.update_user                      AS update_user
FROM       kcoeus.award_person_credit_splits cs
JOIN       kcoeus.award_persons    p   ON p.award_person_id      = cs.award_person_id
LEFT JOIN  kcoeus.inv_credit_type  ict ON ict.inv_credit_type_code = cs.inv_credit_type_code
JOIN       huron_award_version v ON v.award_id = p.award_id

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
