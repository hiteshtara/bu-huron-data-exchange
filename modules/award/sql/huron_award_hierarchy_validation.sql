WITH canonical_hierarchy AS (
    SELECT award_number, root_award_number, parent_award_number
    FROM (
        SELECT h.award_number, h.root_award_number, h.parent_award_number,
               ROW_NUMBER() OVER (
                   PARTITION BY h.award_number
                   ORDER BY CASE WHEN h.active = 'Y' THEN 0 ELSE 1 END,
                            h.update_timestamp    DESC,
                            h.award_hierarchy_id  DESC
               ) AS rn
        FROM   kcoeus.award_hierarchy h
    )
    WHERE rn = 1
), hierarchy_levels AS (
    SELECT award_number, LEVEL AS hierarchy_level
    FROM   canonical_hierarchy
    START WITH parent_award_number = '000000-00000'
    CONNECT BY NOCYCLE PRIOR award_number = parent_award_number
)
SELECT 'raw AWARD_HIERARCHY rows' AS check_name,
       TO_CHAR((SELECT COUNT(*) FROM kcoeus.award_hierarchy)) AS value FROM dual
UNION ALL SELECT 'distinct AWARD_NUMBER in the raw table',
  TO_CHAR((SELECT COUNT(DISTINCT award_number) FROM kcoeus.award_hierarchy)) FROM dual
UNION ALL SELECT 'canonical rows returned by the interface',
  TO_CHAR((SELECT COUNT(*) FROM canonical_hierarchy)) FROM dual
UNION ALL SELECT 'award families (distinct ROOT_AWARD_NUMBER)',
  TO_CHAR((SELECT COUNT(DISTINCT root_award_number) FROM canonical_hierarchy)) FROM dual
UNION ALL SELECT 'root awards (AWARD_NUMBER = ROOT_AWARD_NUMBER)',
  TO_CHAR((SELECT COUNT(*) FROM canonical_hierarchy WHERE award_number = root_award_number)) FROM dual
UNION ALL SELECT 'AWARD_NUMBER business records in AWARD',
  TO_CHAR((SELECT COUNT(DISTINCT award_number) FROM kcoeus.award)) FROM dual
UNION ALL SELECT 'level distribution',
  (SELECT LISTAGG('L' || TO_CHAR(hierarchy_level) || '=' || TO_CHAR(n), '  ')
            WITHIN GROUP (ORDER BY hierarchy_level)
   FROM (SELECT hierarchy_level, COUNT(*) AS n FROM hierarchy_levels GROUP BY hierarchy_level)) FROM dual
UNION ALL SELECT 'families with any award below level 2',
  TO_CHAR((SELECT COUNT(DISTINCT c.root_award_number)
           FROM canonical_hierarchy c JOIN hierarchy_levels l ON l.award_number = c.award_number
           WHERE l.hierarchy_level > 2)) FROM dual
UNION ALL SELECT 'ANOMALY award numbers with more than one raw row',
  TO_CHAR((SELECT COUNT(*) FROM (SELECT award_number FROM kcoeus.award_hierarchy
           GROUP BY award_number HAVING COUNT(*) > 1))) FROM dual
UNION ALL SELECT 'ANOMALY   of those, exact duplicate rows',
  TO_CHAR((SELECT COUNT(*) FROM (SELECT award_number FROM kcoeus.award_hierarchy
           GROUP BY award_number HAVING COUNT(*) > 1
           AND COUNT(DISTINCT root_award_number || '|' || parent_award_number
                     || '|' || NVL(active,'?')) = 1))) FROM dual
UNION ALL SELECT 'ANOMALY   of those, differing only by ACTIVE flag',
  TO_CHAR((SELECT COUNT(*) FROM (SELECT award_number FROM kcoeus.award_hierarchy
           GROUP BY award_number HAVING COUNT(*) > 1 AND COUNT(DISTINCT active) > 1))) FROM dual
UNION ALL SELECT 'ANOMALY   of those, with CONFLICTING parents',
  TO_CHAR((SELECT COUNT(*) FROM (SELECT award_number FROM kcoeus.award_hierarchy
           GROUP BY award_number HAVING COUNT(DISTINCT parent_award_number) > 1))) FROM dual
UNION ALL SELECT 'ANOMALY   conflicting parents, which awards',
  (SELECT LISTAGG(award_number, ', ') WITHIN GROUP (ORDER BY award_number)
   FROM (SELECT award_number FROM kcoeus.award_hierarchy
         GROUP BY award_number HAVING COUNT(DISTINCT parent_award_number) > 1)) FROM dual
UNION ALL SELECT 'ANOMALY   with CONFLICTING roots (expect 0)',
  TO_CHAR((SELECT COUNT(*) FROM (SELECT award_number FROM kcoeus.award_hierarchy
           GROUP BY award_number HAVING COUNT(DISTINCT root_award_number) > 1))) FROM dual
UNION ALL SELECT 'ANOMALY awards in AWARD but missing from the hierarchy',
  (SELECT LISTAGG(award_number, ', ') WITHIN GROUP (ORDER BY award_number)
   FROM (SELECT DISTINCT a.award_number FROM kcoeus.award a
         WHERE NOT EXISTS (SELECT 1 FROM kcoeus.award_hierarchy h
                           WHERE h.award_number = a.award_number))) FROM dual
UNION ALL SELECT 'ANOMALY in the hierarchy but missing from AWARD',
  (SELECT LISTAGG(award_number, ', ') WITHIN GROUP (ORDER BY award_number)
   FROM (SELECT c.award_number FROM canonical_hierarchy c
         WHERE NOT EXISTS (SELECT 1 FROM kcoeus.award a WHERE a.award_number = c.award_number))) FROM dual
UNION ALL SELECT 'RULE roots not ending in -00001 (expect 0)',
  TO_CHAR((SELECT COUNT(DISTINCT root_award_number) FROM canonical_hierarchy
           WHERE root_award_number NOT LIKE '%-00001')) FROM dual
UNION ALL SELECT 'RULE awards ending -00001 that are not a root (expect 0)',
  TO_CHAR((SELECT COUNT(*) FROM canonical_hierarchy
           WHERE award_number LIKE '%-00001' AND award_number <> root_award_number)) FROM dual
UNION ALL SELECT 'RULE awards whose base number differs from their root (expect 0)',
  TO_CHAR((SELECT COUNT(*) FROM canonical_hierarchy
           WHERE SUBSTR(award_number, 1, INSTR(award_number,'-')-1)
              <> SUBSTR(root_award_number, 1, INSTR(root_award_number,'-')-1))) FROM dual

-- Evidence behind huron_award_hierarchy.sql.
--
-- The interface returns one canonical row per AWARD_NUMBER. This query shows what was
-- collapsed to get there and what remains unexplained, so nothing is quietly cleaned up.
--
-- Three source-data anomalies are reported here and deliberately NOT repaired:
--
--   1. 40 award numbers have more than one row in AWARD_HIERARCHY. Ten are exact
--      duplicates, thirty differ only by the ACTIVE flag, and two of those thirty also
--      disagree about the parent. None disagree about the root.
--
--   2. Two awards exist in AWARD with no hierarchy row at all: 200086-00008 and
--      211654-00003. They belong to no family. We did not invent rows for them, and we
--      did not assign them to a root by reading their number - the numbering rule is an
--      observation about how BU allocates numbers, not a relationship KC stores.
--
--   3. One award number, 204946-00004, appears in AWARD_HIERARCHY but not in AWARD.
--
-- WHY 43,201 AND NOT 43,202
-- The canonical hierarchy holds 43,201 award numbers while AWARD holds 43,202. That is
-- not an off-by-one; it reconciles exactly:
--
--     43,202   AWARD_NUMBER business records in AWARD
--     -     2   in AWARD with no hierarchy row (200086-00008, 211654-00003)
--     +     1   in the hierarchy but not in AWARD (204946-00004)
--     = 43,201   award numbers in the canonical hierarchy
--
-- The three RULE checks at the end confirm the -00001 convention still holds. If any of
-- them stops returning 0, the documentation in huron_award_hierarchy.sql needs revisiting.
