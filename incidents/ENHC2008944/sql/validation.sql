-- ENHC2008944 validation. Read-only. Run after any redeploy of either view.
--
-- The recorded results are from 2026-09-11, after the deploy. Numbers marked
-- "KCOEUS" came from this repo's read-only runner; the rest need the SAPBWKCRM
-- owner or SAPBWKCRM_READ_ONLY, because KCOEUS has no grant on AAI_AAT_MAXSEQ.


-- 1. Both views compiled.
--    Result: AWARDS_MAXSEQ VALID (last DDL 2026-09-11 14:30),
--            AAI_AAT_MAXSEQ VALID (last DDL 2026-09-11 14:33).
SELECT OBJECT_NAME,
       STATUS,
       TO_CHAR(LAST_DDL_TIME, 'YYYY-MM-DD HH24:MI') AS LAST_DDL
FROM   DBA_OBJECTS
WHERE  OWNER = 'SAPBWKCRM'
AND    OBJECT_TYPE = 'VIEW'
AND    OBJECT_NAME IN ('AWARDS_MAXSEQ', 'AAI_AAT_MAXSEQ')
ORDER  BY OBJECT_NAME;


-- 2. The column is there, in the right place, with the right type.
--    Result: AWARDS_MAXSEQ column 113, AAI_AAT_MAXSEQ column 38,
--            both VARCHAR2(1). Both PASS.
SELECT TABLE_NAME,
       COLUMN_NAME,
       DATA_TYPE,
       DATA_LENGTH,
       COLUMN_ID,
       CASE WHEN DATA_TYPE = 'VARCHAR2' AND DATA_LENGTH = 1
            THEN 'PASS' ELSE 'FAIL' END AS DATATYPE_CHECK
FROM   DBA_TAB_COLUMNS
WHERE  OWNER = 'SAPBWKCRM'
AND    TABLE_NAME IN ('AWARDS_MAXSEQ', 'AAI_AAT_MAXSEQ')
AND    COLUMN_NAME = 'LIMITED_SUBMISSION_OPPORTUNITY'
ORDER  BY TABLE_NAME;


-- 3. Row count and grain did not move.
--    AWARDS_MAXSEQ before: 43,406 rows / 43,300 distinct AWARD_ID / 106 extra.
--    AWARDS_MAXSEQ after:  43,406 rows / 43,300 distinct AWARD_ID / 106 extra.  (KCOEUS)
--
--    Those 106 extra rows are not new. They come from the PI non-lead-unit join
--    aliased C, which was already in the view. ENHC2008944 did not add a row.
SELECT COUNT(*)                                    AS TOTAL_ROWS,
       COUNT(DISTINCT AWARD_ID)                    AS DISTINCT_AWARD_ID,
       COUNT(*) - COUNT(DISTINCT AWARD_ID)         AS EXTRA_ROWS,
       COUNT(LIMITED_SUBMISSION_OPPORTUNITY)       AS LSO_NON_NULL
FROM   SAPBWKCRM.AWARDS_MAXSEQ;

-- Same for AAI_AAT_MAXSEQ. Capture these before and after any redeploy and
-- compare them; we could not record a baseline here because KCOEUS cannot read
-- this view.
SELECT COUNT(*)                                              AS TOTAL_ROWS,
       COUNT(DISTINCT AWARD_NUMBER)                          AS DISTINCT_AWARD_NUMBER,
       COUNT(DISTINCT AWARD_ID)                              AS DISTINCT_AWARD_ID,
       COUNT(DISTINCT AWARD_NUMBER || '|' || TRANSACTION_ID) AS DISTINCT_AWD_TRAN,
       COUNT(LIMITED_SUBMISSION_OPPORTUNITY)                 AS LSO_NON_NULL
FROM   SAPBWKCRM.AAI_AAT_MAXSEQ;


-- 4. Twenty non-null values.
--    Result: zero rows, and that is correct right now. The attribute is
--    configured in Kuali but nobody has entered a value. Do not read an empty
--    result here as a broken deploy - use check 5 instead.
SELECT *
FROM   (SELECT AWARD_ID,
               AWARD_NUMBER,
               LIMITED_SUBMISSION_OPPORTUNITY
        FROM   SAPBWKCRM.AWARDS_MAXSEQ
        WHERE  LIMITED_SUBMISSION_OPPORTUNITY IS NOT NULL)
WHERE  ROWNUM <= 20;

SELECT *
FROM   (SELECT AWARD_ID,
               AWARD_NUMBER,
               LIMITED_SUBMISSION_OPPORTUNITY
        FROM   SAPBWKCRM.AAI_AAT_MAXSEQ
        WHERE  LIMITED_SUBMISSION_OPPORTUNITY IS NOT NULL)
WHERE  ROWNUM <= 20;


-- 5. Proof the plumbing works while the field is still empty.
--    Result 2026-09-11: 12,902 rows for attribute 9, 0 of them non-null. (KCOEUS)
--    So the column resolves and the join reaches AWARD_CUSTOM_DATA; there is
--    simply nothing to show yet.
SELECT COUNT(*)     AS ATTR9_ROWS,
       COUNT(VALUE) AS ATTR9_NON_NULL
FROM   KCOEUS.AWARD_CUSTOM_DATA
WHERE  CUSTOM_ATTRIBUTE_ID = 9;


-- 6. AWARD_CUSTOM_DATA is one row per AWARD_ID, which is why joining it cannot
--    add rows. Expect zero rows.
SELECT AWARD_ID,
       COUNT(*) AS DUPES
FROM   SAPBWKCRM.AWARD_CUSTOM_DATA
GROUP  BY AWARD_ID
HAVING COUNT(*) > 1;


-- 7. AAI_AAT_MAXSEQ is a UNION, so check the new column did not split rows that
--    used to be identical. It cannot, because the value is functionally
--    dependent on AWARD_ID and both branches select AWARD_ID. Expect zero rows.
SELECT AWARD_ID,
       COUNT(DISTINCT LIMITED_SUBMISSION_OPPORTUNITY) AS DISTINCT_VALS
FROM   SAPBWKCRM.AAI_AAT_MAXSEQ
GROUP  BY AWARD_ID
HAVING COUNT(DISTINCT LIMITED_SUBMISSION_OPPORTUNITY) > 1;


-- 8. What the dependent objects look like.
--    Result 2026-09-11: four objects depend on these two views.
--    AWARD_PROPOSAL_BRIDGE and REPORT_PARENT_AWARDS are VALID.
--    PROTOCOL_FUNDING_SOURCE and SUBAWARD_FUNDING_SOURCE_MAXSEQ are INVALID.
--
--    Their LAST_DDL_TIME values align with a pre-existing June 15, 2026
--    invalid-object group; because no pre-deployment invalid-object snapshot
--    was captured, the current invalid state cannot be conclusively attributed
--    to or excluded from ENHC2008944. Both are HARD dependents of
--    AWARDS_MAXSEQ, so this deploy would have marked them stale too.
--
--    Neither has compile errors in DBA_ERRORS, neither references
--    LIMITED_SUBMISSION_OPPORTUNITY, and every upstream object they reference
--    is VALID. See the README for the full reasoning.
SELECT D.OWNER,
       D.NAME,
       D.TYPE,
       O.STATUS
FROM   DBA_DEPENDENCIES D
JOIN   DBA_OBJECTS O
       ON  O.OWNER       = D.OWNER
       AND O.OBJECT_NAME = D.NAME
       AND O.OBJECT_TYPE = D.TYPE
WHERE  D.REFERENCED_OWNER = 'SAPBWKCRM'
AND    D.REFERENCED_NAME IN ('AWARDS_MAXSEQ', 'AAI_AAT_MAXSEQ')
ORDER  BY D.OWNER, D.NAME;
