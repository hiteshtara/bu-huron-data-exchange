-- DEMO 2 - Why MAX(SEQUENCE_NUMBER) is not the current award.
--
-- This is the query that justifies the whole version-selection rule. The obvious
-- approach - take the highest sequence per award number - returns MORE rows than
-- there are awards, because some award numbers carry two rows at the same highest
-- sequence: one ACTIVE and one ARCHIVED.
--
-- Every row this returns is an award where "take the latest" has to pick between
-- two rows, and picking wrong hands Huron an archived record as the record of
-- record.
--
-- Read-only.

WITH max_sequence_per_award AS (
    SELECT a.award_number,
           MAX(a.sequence_number) AS max_sequence_number
    FROM   kcoeus.award a
    GROUP  BY a.award_number
), rows_at_max_sequence AS (
    -- every AWARD row that sits at its award number's highest sequence
    SELECT a.award_number,
           a.award_id,
           a.sequence_number,
           a.award_sequence_status,
           a.title
    FROM   kcoeus.award            a
    JOIN   max_sequence_per_award  m
           ON  m.award_number        = a.award_number
           AND m.max_sequence_number = a.sequence_number
), contested AS (
    -- award numbers where that is more than one row
    SELECT r.award_number
    FROM   rows_at_max_sequence r
    GROUP  BY r.award_number
    HAVING COUNT(*) > 1
)
SELECT r.award_number,
       r.award_id,
       r.sequence_number,
       r.award_sequence_status,
       SUBSTR(r.title, 1, 60) AS award_title
FROM   rows_at_max_sequence r
JOIN   contested            c ON c.award_number = r.award_number
ORDER  BY r.award_number,
          CASE WHEN r.award_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END
