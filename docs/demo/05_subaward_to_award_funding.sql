-- DEMO 5 - The cross-module join, and the decision hiding inside it.
--
-- SUBAWARD_FUNDING_SOURCE.AWARD_ID points at one specific AWARD row - a single
-- award VERSION - not at the award as a whole. KC records the version that existed
-- when the subaward was funded.
--
-- This query shows how often that recorded version is no longer the current one.
-- It is the evidence behind decision D-01, and it is a good one to run live because
-- the answer is not what people expect.
--
-- Read-only.

WITH current_subaward AS (
    -- one row per subaward code, the same rule the module SQL uses
    SELECT subaward_id, subaward_code
    FROM (
        SELECT s.subaward_id,
               s.subaward_code,
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
), current_award AS (
    -- one row per award number, so we can ask "is the funded version still current?"
    SELECT award_id, award_number
    FROM (
        SELECT a.award_id,
               a.award_number,
               ROW_NUMBER() OVER (
                   PARTITION BY a.award_number
                   ORDER BY CASE WHEN a.award_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            a.sequence_number DESC,
                            a.award_id        DESC
               ) AS rn
        FROM   kcoeus.award a
    )
    WHERE rn = 1
), funding_links AS (
    SELECT f.subaward_funding_source_id,
           CASE WHEN cur.award_id IS NOT NULL
                THEN 'Still the current Award version'
                ELSE 'Superseded Award version'
           END AS funding_link_state
    FROM       kcoeus.subaward_funding_source f
    JOIN       current_subaward v   ON v.subaward_id = f.subaward_id
    LEFT JOIN  current_award    cur ON cur.award_id  = f.award_id
)
SELECT l.funding_link_state,
       COUNT(*)                                                    AS funding_rows,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)            AS pct_of_funding_rows
FROM   funding_links l
GROUP  BY l.funding_link_state
ORDER  BY funding_rows DESC
