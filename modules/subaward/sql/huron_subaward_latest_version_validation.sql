WITH per_code AS (
    SELECT subaward_code,
           MAX(sequence_number) AS max_sequence_number,
           SUM(CASE WHEN subaward_sequence_status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_rows
    FROM   kcoeus.subaward
    GROUP  BY subaward_code
), max_rows AS (
    SELECT s.subaward_code, s.subaward_id, s.sequence_number
    FROM   kcoeus.subaward s
    JOIN   per_code p ON p.subaward_code       = s.subaward_code
                     AND p.max_sequence_number = s.sequence_number
), selected AS (
    SELECT subaward_id, subaward_code, selection_rule
    FROM (
        SELECT s.subaward_id,
               s.subaward_code,
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
    (SELECT COUNT(*)                      FROM kcoeus.subaward)  AS total_subaward_rows,
    (SELECT COUNT(DISTINCT subaward_code) FROM kcoeus.subaward)  AS distinct_subaward_codes,
    (SELECT COUNT(*)                      FROM max_rows)         AS max_sequence_rows,
    (SELECT COUNT(DISTINCT subaward_code) FROM max_rows)         AS max_sequence_distinct_codes,
    (SELECT COUNT(*) FROM (SELECT subaward_code FROM max_rows
                           GROUP BY subaward_code HAVING COUNT(*) > 1))
                                                                 AS duplicate_max_sequence_codes,
    (SELECT COUNT(*) FROM per_code WHERE active_rows = 1)        AS subawards_with_one_active,
    (SELECT COUNT(*) FROM per_code WHERE active_rows = 0)        AS subawards_with_no_active,
    (SELECT COUNT(*) FROM per_code WHERE active_rows > 1)        AS subawards_with_many_active,
    (SELECT COUNT(*) FROM kcoeus.subaward s
      JOIN per_code p ON p.subaward_code = s.subaward_code
     WHERE s.subaward_sequence_status = 'ACTIVE'
       AND s.sequence_number <> p.max_sequence_number)           AS active_not_at_max_sequence,
    (SELECT COUNT(*) FROM selected)                              AS selected_root_rows,
    (SELECT COUNT(DISTINCT subaward_code) FROM selected)         AS selected_distinct_codes,
    (SELECT COUNT(*) FROM selected WHERE selection_rule = 'ACTIVE_STATUS')
                                                                 AS selected_by_active_status,
    (SELECT COUNT(*) FROM selected WHERE selection_rule = 'MAX_SEQUENCE_FALLBACK')
                                                                 AS selected_by_max_sequence
FROM dual

-- Validates the Huron Subaward root population rule.
--
-- Subaward is a THIRD versioning pattern -- neither Award's nor Institutional
-- Proposal's selector was reused, and each clause below is justified by production
-- evidence:
--
-- 1. ACTIVE FIRST, ahead of sequence number.
--    62 subaward codes carry duplicate rows at their maximum sequence. 61 of those 62
--    are ACTIVE + one-or-more ARCHIVED rows sharing a sequence, so ACTIVE identifies
--    the current record cleanly. Separately, 5 codes have their ACTIVE row BELOW the
--    maximum sequence, and in all 5 the higher row is PENDING -- an amendment in
--    progress, not yet the record of record. Ordering by sequence first would pick
--    those PENDING rows, so ACTIVE is evaluated first.
--
-- 2. Then highest SEQUENCE_NUMBER, for ordinary families.
--
-- 3. Then latest UPDATE_TIMESTAMP. Exactly one code (747) has TWO ACTIVE rows, both at
--    sequence 3 and both KEW-finalized. They are not equivalent: subaward_id 3850 was
--    finalized 92 seconds after 3849 and carries a SUBAWARD_AMOUNT_INFO row that 3849
--    does not. The later, more complete record is the intended one, so the tie-break
--    is business evidence rather than an arbitrary surrogate key. Verified: no ACTIVE
--    max-sequence group ties on UPDATE_TIMESTAMP anywhere in production.
--
-- 4. Then highest SUBAWARD_ID -- a deterministic backstop only; it is never reached
--    with current data.
--
-- The fallback branch preserves the 3 codes with no ACTIVE row (1427 CANCELED, 3699
-- and 3912 PENDING). All three are single-row families, so nothing is lost.
-- SELECTION_RULE records which branch chose each row; nothing is silently dropped.
