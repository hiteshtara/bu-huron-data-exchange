WITH canonical_hierarchy AS (
    SELECT award_hierarchy_id, award_number, root_award_number, parent_award_number,
           originating_award_number, active, ver_nbr, update_timestamp, update_user
    FROM (
        SELECT h.award_hierarchy_id,
               h.award_number,
               h.root_award_number,
               h.parent_award_number,
               h.originating_award_number,
               h.active,
               h.ver_nbr,
               h.update_timestamp,
               h.update_user,
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
SELECT
       c.award_hierarchy_id                AS award_hierarchy_id,
       c.award_number                      AS award_number,
       c.root_award_number                 AS root_award_number,
       c.parent_award_number               AS parent_award_number,
       c.originating_award_number          AS originating_award_number,
       CASE WHEN c.award_number = c.root_award_number THEN 'Y' ELSE 'N' END
                                           AS is_root_award,
       l.hierarchy_level                   AS hierarchy_level,
       c.active                            AS active_flag,
       c.ver_nbr                           AS version_number,
       c.update_timestamp                  AS update_timestamp,
       c.update_user                       AS update_user
FROM       canonical_hierarchy c
LEFT JOIN  hierarchy_levels    l ON l.award_number = c.award_number

-- HOW BU's AWARDS ROLL UP INTO AWARD FAMILIES
--
-- There are two completely different things going on in an award number, and mixing
-- them up is the main risk this dataset exists to prevent.
--
--   AWARD_NUMBER hierarchy = the award-family / account structure.
--       123456-00001 is the main award for one funded project.
--       123456-00002, -00003 ... are separate subaccounts in the same family.
--       These are DIFFERENT award records.
--
--   SEQUENCE_NUMBER = version history of ONE award record.
--       123456-00001 sequence 1, 2, 3 are the same account edited over time.
--       These are the SAME award record.
--
-- So 43,202 award business records roll up into 15,729 award families - about 2.7
-- awards each. The largest family, 207805-00001, holds 216 awards.
--
-- What we verified in production:
--   * Every one of the 15,729 roots ends in -00001, and every award ending in -00001
--     is a root. The rule holds in both directions. We still derive IS_ROOT_AWARD from
--     AWARD_NUMBER = ROOT_AWARD_NUMBER rather than from the suffix, because that is
--     what KC actually stores; both give 15,729 today.
--   * Every award in a family shares its root's base number. No family mixes bases.
--   * Children are genuinely separate accounts: 27,170 have their own ACCOUNT_NUMBER
--     and NONE shares the root's account number. "Subaccount" is accurate.
--   * Roots do not have a NULL parent. They carry the sentinel '000000-00000', which
--     is what the CONNECT BY starts from.
--   * Nesting is real but rare. Levels: 15,729 roots, 27,368 at level 2, 101 at
--     level 3, 3 at level 4. Only 23 of 15,729 families go deeper than level 2, so
--     read HIERARCHY_LEVEL rather than assuming two tiers.
--
-- CANONICALIZATION
-- AWARD_HIERARCHY holds 43,241 rows for 43,201 award numbers - 40 award numbers appear
-- more than once. We return exactly ONE row per AWARD_NUMBER, preferring ACTIVE = 'Y',
-- then the latest UPDATE_TIMESTAMP, then the highest AWARD_HIERARCHY_ID. Verified
-- deterministic: no award number ties on (active, timestamp).
--
-- That choice matters for two awards. 200431-00004 and 201514-00005 each have an
-- inactive row placing them one level deeper and an active row re-parenting them
-- directly under the root. We take the active placement, which is why level 3 shows
-- 101 here against 103 in the raw table.
--
-- Nothing is hidden by this. huron_award_hierarchy_validation.sql reports every
-- duplicate, every conflict, and the awards missing from the hierarchy entirely.
