/*
Purpose:     Discover the KC Grants schema and emit a data dictionary for Huron AI mapping.
Module:      Grants (Proposal Dev, Institutional Proposal, Award, Subaward, Negotiation, Common)
Environment: KC / Oracle  (run in a READ-ONLY reporting connection)
Source:      Oracle data dictionary views (ALL_TABLES / ALL_TAB_COLUMNS / ALL_TAB_COMMENTS)
Target:      CSV -> bu_grants_dump_for_huron/01_data_dictionary.csv
Author:      BU Huron Data Exchange
Date:        2026-08-07

Business rule:
  Phil (Huron) wants FIELDS over ROWS with clearly-defined column headers. The most valuable
  single artifact is a complete data dictionary generated from BU's ACTUAL KC instance, so we
  never assume a table/column exists (per project rule). Run this FIRST; it also tells you the
  exact object names to confirm the module extract scripts against.

Validation:
  Row count of section (2) == "Columns documented" in the manifest.
  Section (1) count == "Tables discovered".

HOW TO USE:
  1. Set the KC schema owner in the &&kc_owner prompt. Confirmed owner for BU = KCOEUS (staging).
  2. Run section (1) to see the table inventory the pattern list captured.
  3. Adjust the pattern list in the WITH grants_table_scope block until the inventory looks right
     (add/remove BU-specific tables). Do NOT guess — verify each against section (1).
  4. Run section (2) to produce the data dictionary CSV.
  5. Run section (3) to auto-generate sample-extract SELECTs for the row samples.
*/

-- Schema owner for KC (CONFIRM against BU's instance; do not assume).
-- In SQL*Plus:  DEFINE kc_owner = 'KCOEUS'
-- Or replace &&kc_owner inline with the literal owner.

/* ------------------------------------------------------------------ */
/* Scope: the KC Grants table-name patterns. Verify every match in (1) */
/* ------------------------------------------------------------------ */
-- These LIKE patterns target the standard Kuali Coeus Grants schema. BU customizations may add
-- or rename tables — treat section (1) output as the authority, not this list.
WITH grants_table_scope AS (
    SELECT owner, table_name
    FROM   all_tables
    WHERE  owner = UPPER('&&kc_owner')
    AND    (
              -- Proposal Development (pre-award, in-progress)
              table_name LIKE 'EPS_PROP%'          -- proposal dev header + children
           OR table_name LIKE 'NARRATIVE%'         -- proposal attachments/narrative metadata
           OR table_name LIKE 'PROP_PERSON%'
              -- Institutional Proposal (proposal of record)
           OR table_name LIKE 'INSTITUTIONAL_PROP%'
           OR table_name LIKE 'INST_PROP%'
              -- Award
           OR table_name LIKE 'AWARD%'
              -- Subaward
           OR table_name LIKE 'SUBAWARD%'
              -- Negotiation
           OR table_name LIKE 'NEGOTIATION%'
              -- Budget (shared by proposal + award)
           OR table_name LIKE 'BUDGET%'
              -- Common / reference / dimensions
           OR table_name IN ('SPONSOR','SPONSOR_HIERARCHY','ROLODEX','UNIT',
                             'RATE_TYPE','SCIENCE_KEYWORD','NSF_CODE')
           OR table_name LIKE '%_STATUS'           -- status lookups
           OR table_name LIKE '%_TYPE'             -- type lookups
              -- Custom attributes (BU-added fields) — high value, easily missed
           OR table_name LIKE 'CUSTOM_ATTRIBUTE%'
           OR table_name LIKE '%_CUSTOM_DATA'
           )
)

/* ---------------------------------------------------------------- */
/* (1) Table inventory — REVIEW THIS before trusting the extracts    */
/* ---------------------------------------------------------------- */
SELECT s.table_name,
       t.num_rows                    AS approx_rows,   -- from stats; may be stale
       tc.comments                   AS table_comment
FROM   grants_table_scope s
JOIN   all_tables       t  ON t.owner = s.owner AND t.table_name = s.table_name
LEFT   JOIN all_tab_comments tc
       ON tc.owner = s.owner AND tc.table_name = s.table_name AND tc.table_type = 'TABLE'
ORDER  BY s.table_name;


/* ---------------------------------------------------------------- */
/* (2) DATA DICTIONARY  -> 01_data_dictionary.csv                    */
/*     One row per column. This is the core deliverable to Huron.    */
/* ---------------------------------------------------------------- */
-- Re-declare the scope CTE because each statement is standalone in SQL*Plus.
WITH grants_table_scope AS (
    SELECT owner, table_name
    FROM   all_tables
    WHERE  owner = UPPER('&&kc_owner')
    AND    (   table_name LIKE 'EPS_PROP%'
           OR  table_name LIKE 'NARRATIVE%'
           OR  table_name LIKE 'PROP_PERSON%'
           OR  table_name LIKE 'INSTITUTIONAL_PROP%'
           OR  table_name LIKE 'INST_PROP%'
           OR  table_name LIKE 'AWARD%'
           OR  table_name LIKE 'SUBAWARD%'
           OR  table_name LIKE 'NEGOTIATION%'
           OR  table_name LIKE 'BUDGET%'
           OR  table_name IN ('SPONSOR','SPONSOR_HIERARCHY','ROLODEX','UNIT',
                             'RATE_TYPE','SCIENCE_KEYWORD','NSF_CODE')
           OR  table_name LIKE '%_STATUS'
           OR  table_name LIKE '%_TYPE'
           OR  table_name LIKE 'CUSTOM_ATTRIBUTE%'
           OR  table_name LIKE '%_CUSTOM_DATA'
           )
)
SELECT c.table_name,
       c.column_id                              AS column_order,
       c.column_name,
       c.data_type,
       -- readable length/precision, e.g. VARCHAR2(40), NUMBER(12,2), DATE
       CASE
         WHEN c.data_type IN ('VARCHAR2','CHAR','NVARCHAR2','NCHAR')
              THEN c.data_type || '(' || c.char_length || ')'
         WHEN c.data_type = 'NUMBER' AND c.data_precision IS NOT NULL
              THEN c.data_type || '(' || c.data_precision ||
                   CASE WHEN NVL(c.data_scale,0) > 0 THEN ',' || c.data_scale END || ')'
         ELSE c.data_type
       END                                      AS data_type_full,
       c.nullable                               AS is_nullable,   -- Y = nullable, N = required
       c.data_default                           AS column_default,
       cc.comments                              AS column_comment
FROM   grants_table_scope s
JOIN   all_tab_columns c
       ON c.owner = s.owner AND c.table_name = s.table_name
LEFT   JOIN all_col_comments cc
       ON cc.owner = c.owner AND cc.table_name = c.table_name AND cc.column_name = c.column_name
ORDER  BY c.table_name, c.column_id;


/* ---------------------------------------------------------------- */
/* (3) Sample-extract generator                                     */
/*     Emits a ready-to-run SELECT per in-scope table (first 1000    */
/*     rows). Spool the output, review, then run to produce samples. */
/*     Reference/lookup tables should be extracted in FULL instead   */
/*     (remove the FETCH clause for those) — see grants_common_*.sql */
/* ---------------------------------------------------------------- */
WITH grants_table_scope AS (
    SELECT owner, table_name
    FROM   all_tables
    WHERE  owner = UPPER('&&kc_owner')
    AND    (   table_name LIKE 'EPS_PROP%'   OR table_name LIKE 'NARRATIVE%'
           OR  table_name LIKE 'PROP_PERSON%' OR table_name LIKE 'INSTITUTIONAL_PROP%'
           OR  table_name LIKE 'INST_PROP%'  OR table_name LIKE 'AWARD%'
           OR  table_name LIKE 'SUBAWARD%'   OR table_name LIKE 'NEGOTIATION%'
           OR  table_name LIKE 'BUDGET%'
           OR  table_name IN ('SPONSOR','SPONSOR_HIERARCHY','ROLODEX','UNIT',
                             'RATE_TYPE','SCIENCE_KEYWORD','NSF_CODE')
           OR  table_name LIKE '%_STATUS'    OR table_name LIKE '%_TYPE'
           OR  table_name LIKE 'CUSTOM_ATTRIBUTE%' OR table_name LIKE '%_CUSTOM_DATA'
           )
)
SELECT 'SELECT * FROM ' || owner || '.' || table_name
       || ' FETCH FIRST 1000 ROWS ONLY;'   AS sample_extract_sql
FROM   grants_table_scope
ORDER  BY table_name;
