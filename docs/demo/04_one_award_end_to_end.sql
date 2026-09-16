-- DEMO 4 - One real award, hydrated.
--
-- Picks the current version of a single award the same way the module SQL does,
-- then counts every child collection hanging off it. This is the query that shows
-- why the child collections are separate datasets rather than one wide join:
-- multiply the people, terms and custom fields together and you get the row count
-- a single joined result would have produced.
--
-- CHANGE THE AWARD NUMBER BELOW to demo a different one. 207805-00001 is the root
-- of BU's largest award family.
--
-- Read-only.

WITH demo_award AS (
    SELECT '207805-00001' AS award_number FROM dual     -- <<<< change this
), selected_award AS (
    SELECT award_id, award_number, sequence_number, title,
           award_sequence_status, selection_rule
    FROM (
        SELECT a.award_id,
               a.award_number,
               a.sequence_number,
               a.title,
               a.award_sequence_status,
               CASE WHEN a.award_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY a.award_number
                   ORDER BY CASE WHEN a.award_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            a.sequence_number DESC,
                            a.award_id        DESC
               ) AS rn
        FROM   kcoeus.award a
        JOIN   demo_award   d ON d.award_number = a.award_number
    )
    WHERE rn = 1
)
SELECT s.award_number,
       s.award_id,
       s.sequence_number,
       s.award_sequence_status,
       s.selection_rule,
       SUBSTR(s.title, 1, 60)                                                   AS award_title,
       (SELECT COUNT(*) FROM kcoeus.award_persons       x WHERE x.award_id = s.award_id) AS people,
       (SELECT COUNT(*) FROM kcoeus.award_amount_info   x WHERE x.award_id = s.award_id) AS amount_rows,
       (SELECT COUNT(*) FROM kcoeus.award_sponsor_term  x WHERE x.award_id = s.award_id) AS sponsor_terms,
       (SELECT COUNT(*) FROM kcoeus.award_report_terms  x WHERE x.award_id = s.award_id) AS report_terms,
       (SELECT COUNT(*) FROM kcoeus.award_special_review x WHERE x.award_id = s.award_id) AS special_reviews,
       (SELECT COUNT(*) FROM kcoeus.award_custom_data   x WHERE x.award_id = s.award_id) AS custom_fields,
       (SELECT COUNT(*) FROM kcoeus.award_cost_share    x WHERE x.award_id = s.award_id) AS cost_share_rows,
       (SELECT COUNT(*) FROM kcoeus.award_attachment    x WHERE x.award_id = s.award_id) AS attachments,
       (SELECT COUNT(*) FROM kcoeus.award_comment       x WHERE x.award_id = s.award_id) AS comments,
       /* what a single flat join would have cost, on just three collections */
       (SELECT GREATEST(COUNT(*), 1) FROM kcoeus.award_persons      x WHERE x.award_id = s.award_id)
       * (SELECT GREATEST(COUNT(*), 1) FROM kcoeus.award_sponsor_term x WHERE x.award_id = s.award_id)
       * (SELECT GREATEST(COUNT(*), 1) FROM kcoeus.award_custom_data  x WHERE x.award_id = s.award_id)
                                                                                AS rows_if_joined_flat
FROM   selected_award s
