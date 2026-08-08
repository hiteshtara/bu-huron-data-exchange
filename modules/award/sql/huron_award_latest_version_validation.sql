WITH max_seq AS (
    SELECT award_number, MAX(sequence_number) AS max_sequence_number
    FROM   kcoeus.award
    GROUP  BY award_number
), max_seq_rows AS (
    SELECT a.award_id, a.award_number, a.sequence_number
    FROM   kcoeus.award a
    JOIN   max_seq m ON m.award_number        = a.award_number
                    AND m.max_sequence_number = a.sequence_number
), selected AS (
    SELECT award_id, award_number, selection_rule
    FROM (
        SELECT a.award_id,
               a.award_number,
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
    (SELECT COUNT(*)                     FROM kcoeus.award)   AS total_award_rows,
    (SELECT COUNT(DISTINCT award_number) FROM kcoeus.award)   AS distinct_award_numbers,
    (SELECT COUNT(*)                     FROM max_seq_rows)   AS latest_award_rows,
    (SELECT COUNT(DISTINCT award_number) FROM max_seq_rows)   AS latest_distinct_award_numbers,
    (SELECT COUNT(*) FROM (SELECT award_number FROM max_seq_rows
                           GROUP BY award_number HAVING COUNT(*) > 1))
                                                              AS duplicate_max_sequence_awards,
    (SELECT COUNT(*) FROM selected)                           AS selected_root_rows,
    (SELECT COUNT(DISTINCT award_number) FROM selected)       AS selected_distinct_award_numbers,
    (SELECT COUNT(*) FROM selected WHERE selection_rule = 'ACTIVE_STATUS')
                                                              AS selected_by_active_status,
    (SELECT COUNT(*) FROM selected WHERE selection_rule = 'MAX_SEQUENCE_FALLBACK')
                                                              AS selected_by_max_sequence
FROM dual

-- Validates the Huron Award root population rule.
--
-- MAX(SEQUENCE_NUMBER) alone is NOT one row per award: 43,212 rows for 43,202
-- award numbers, because 10 award numbers carry two rows at the same maximum
-- sequence (an ARCHIVED/CANCELED row and an ACTIVE row sharing one sequence).
--
-- KC maintains its own version marker, AWARD_SEQUENCE_STATUS, and it is exact:
-- 43,000 award numbers have exactly one ACTIVE row and none have more than one.
-- The remaining 202 award numbers have NO ACTIVE row at all (only ARCHIVED,
-- CANCELED or PENDING) and would be lost by filtering on ACTIVE alone.
--
-- The selector therefore prefers AWARD_SEQUENCE_STATUS = 'ACTIVE' and falls back
-- to the highest sequence, tie-broken on the highest AWARD_ID, so it is
-- deterministic and returns exactly one row per AWARD_NUMBER. SELECTION_RULE
-- records which branch chose each row -- nothing is silently deduplicated.
