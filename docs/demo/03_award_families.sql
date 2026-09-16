-- DEMO 3 - How awards roll up into families.
--
-- The three-level problem, in one result. An Award family is the root -00001
-- award plus its child/subaccount awards; each of those separately has its own
-- version history.
--
-- Shows the family-size distribution, so the "43,202 awards but 15,729 funded
-- projects" point lands with the shape behind it rather than as a bare number.
--
-- AWARD_HIERARCHY holds a few award numbers twice, differing only by the ACTIVE
-- flag, so we pick one row per award number the same way the module SQL does -
-- ACTIVE first, then the latest timestamp, then the highest id.
--
-- Read-only.

WITH canonical_hierarchy AS (
    SELECT award_number,
           root_award_number,
           parent_award_number
    FROM (
        SELECT h.award_number,
               h.root_award_number,
               h.parent_award_number,
               ROW_NUMBER() OVER (
                   PARTITION BY h.award_number
                   ORDER BY CASE WHEN h.active = 'Y' THEN 0 ELSE 1 END,
                            h.update_timestamp    DESC,
                            h.award_hierarchy_id  DESC
               ) AS rn
        FROM   kcoeus.award_hierarchy h
    )
    WHERE rn = 1
), family_sizes AS (
    SELECT c.root_award_number,
           COUNT(*) AS awards_in_family
    FROM   canonical_hierarchy c
    GROUP  BY c.root_award_number
), banded AS (
    SELECT f.awards_in_family,
           CASE WHEN f.awards_in_family = 1                      THEN '1 award (family of one)'
                WHEN f.awards_in_family BETWEEN 2   AND 5        THEN '2-5 awards'
                WHEN f.awards_in_family BETWEEN 6   AND 20       THEN '6-20 awards'
                WHEN f.awards_in_family BETWEEN 21  AND 100      THEN '21-100 awards'
                ELSE                                                  'over 100 awards'
           END AS family_size_band,
           CASE WHEN f.awards_in_family = 1                      THEN 1
                WHEN f.awards_in_family BETWEEN 2   AND 5        THEN 2
                WHEN f.awards_in_family BETWEEN 6   AND 20       THEN 3
                WHEN f.awards_in_family BETWEEN 21  AND 100      THEN 4
                ELSE                                                  5
           END AS band_order
    FROM   family_sizes f
)
SELECT b.family_size_band,
       COUNT(*)                   AS families,
       SUM(b.awards_in_family)    AS awards_covered
FROM   banded b
GROUP  BY b.family_size_band, b.band_order
ORDER  BY b.band_order
