WITH per_prop AS (
    SELECT proposal_number,
           MAX(sequence_number) AS max_sequence_number,
           SUM(CASE WHEN proposal_sequence_status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_rows
    FROM   kcoeus.proposal
    GROUP  BY proposal_number
), max_seq_rows AS (
    SELECT p.proposal_number, p.proposal_id, p.sequence_number
    FROM   kcoeus.proposal p
    JOIN   per_prop pp ON pp.proposal_number     = p.proposal_number
                      AND pp.max_sequence_number = p.sequence_number
), selected AS (
    SELECT proposal_id, proposal_number, selection_rule
    FROM (
        SELECT p.proposal_id,
               p.proposal_number,
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
    (SELECT COUNT(*)                       FROM kcoeus.proposal) AS total_proposal_rows,
    (SELECT COUNT(DISTINCT proposal_number) FROM kcoeus.proposal) AS distinct_proposal_numbers,
    (SELECT COUNT(*)                       FROM max_seq_rows)    AS max_sequence_rows,
    (SELECT COUNT(*) FROM (SELECT proposal_number FROM max_seq_rows
                           GROUP BY proposal_number HAVING COUNT(*) > 1))
                                                                 AS duplicate_max_sequence_proposals,
    (SELECT COUNT(*) FROM per_prop WHERE active_rows = 1)        AS proposals_with_one_active,
    (SELECT COUNT(*) FROM per_prop WHERE active_rows = 0)        AS proposals_with_no_active,
    (SELECT COUNT(*) FROM per_prop WHERE active_rows > 1)        AS proposals_with_many_active,
    (SELECT COUNT(*) FROM kcoeus.proposal p
      JOIN per_prop pp ON pp.proposal_number = p.proposal_number
     WHERE p.proposal_sequence_status = 'ACTIVE'
       AND p.sequence_number <> pp.max_sequence_number)          AS active_not_at_max_sequence,
    (SELECT COUNT(*) FROM selected)                              AS selected_root_rows,
    (SELECT COUNT(DISTINCT proposal_number) FROM selected)       AS selected_distinct_proposal_numbers,
    (SELECT COUNT(*) FROM selected WHERE selection_rule = 'ACTIVE_STATUS')
                                                                 AS selected_by_active_status,
    (SELECT COUNT(*) FROM selected WHERE selection_rule = 'MAX_SEQUENCE_FALLBACK')
                                                                 AS selected_by_max_sequence
FROM dual

-- Validates the Huron Institutional Proposal root population rule.
--
-- The Proposal picture is the INVERSE of Award, so Award's selector was NOT
-- reused unchanged:
--
--   * MAX(SEQUENCE_NUMBER) is perfectly unique here - 36,863 rows for 36,863
--     proposal numbers, zero duplicates (Award had 10). Structurally it works.
--   * But it selects the WRONG version. For 80 proposal numbers the ACTIVE row is
--     NOT the highest sequence, and the higher row is CANCELED (66), PENDING (10)
--     or ARCHIVED (3). Taking the maximum sequence would hand Huron cancelled or
--     in-progress versions as the record of record.
--   * PROPOSAL_SEQUENCE_STATUS = 'ACTIVE' is therefore the semantically correct
--     marker, but it is not unique on its own: 36,810 proposal numbers have exactly
--     one ACTIVE row, 52 have none, and 1 (proposal 01104505) has TWO.
--
-- The selector prefers ACTIVE, then the highest sequence within that preference,
-- then the highest PROPOSAL_ID. That resolves the double-ACTIVE proposal
-- deterministically, keeps the 52 ACTIVE-less proposals via the fallback branch,
-- and returns exactly one row per PROPOSAL_NUMBER. SELECTION_RULE records which
-- branch chose each row -- nothing is silently deduplicated.
