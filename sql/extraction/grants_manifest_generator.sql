/*
Purpose:     Auto-generate 02_table_manifest.csv for the Huron Grants dump.
Module:      Grants (all domains)
Environment: KC / Oracle — KCOEUS staging schema (read-only)
Source:      Oracle data dictionary (ALL_TABLES / ALL_TAB_COLUMNS / ALL_CONSTRAINTS)
Target:      CSV -> bu_grants_dump_for_huron/02_table_manifest.csv
Author:      BU Huron Data Exchange
Date:        2026-08-07

Business rule:
  One row per in-scope table describing WHAT was sent and HOW:
    - EXTRACT_TYPE: FULL for reference/master/lookup tables (complete population);
      SAMPLE for large transactional/history/custom-data tables (representative rows,
      ALL columns + lineage keys retained).
  Source object names are CONFIRMED from the KCOEUS staging schema (this script reads
  the live dictionary — it never assumes a table/column exists).

  This package is for Huron FIELD DISCOVERY and AI MAPPING, not final migration
  cleansing or final population selection.

Validation:
  Manifest row count == "Tables extracted" in the reconciliation counts.
  Every EXTRACT_TYPE=FULL table must be a small reference/lookup; every SAMPLE table
  must show at least the lineage keys in LINEAGE_KEYS.

HOW TO USE:
  SQL*Plus:  SET SERVEROUTPUT ON SIZE UNLIMITED
             SPOOL 02_table_manifest.csv
             @grants_manifest_generator.sql
             SPOOL OFF
  The block prints a CSV header + one classified row per table WITH EXACT COUNTS
  (dynamic COUNT(*) per table). Columns are pipe-delimited within key lists so the
  CSV stays comma-safe.
*/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF

DECLARE
  k_owner   CONSTANT VARCHAR2(30) := 'KCOEUS';   -- confirmed staging schema owner
  v_cnt     NUMBER;
  v_type    VARCHAR2(10);
  v_domain  VARCHAR2(40);
  v_folder  VARCHAR2(40);
BEGIN
  DBMS_OUTPUT.PUT_LINE(
    'domain,source_table,extract_type,target_file,pk_columns,lineage_keys,row_count,notes');

  FOR t IN (
    SELECT at.table_name,
           -- pipe-joined primary key columns
           ( SELECT LISTAGG(acc.column_name, '|') WITHIN GROUP (ORDER BY acc.position)
             FROM   all_constraints ac
             JOIN   all_cons_columns acc
               ON   acc.owner = ac.owner AND acc.constraint_name = ac.constraint_name
             WHERE  ac.owner = at.owner AND ac.table_name = at.table_name
             AND    ac.constraint_type = 'P' )                          AS pk_cols,
           -- lineage keys present in this table
           ( SELECT LISTAGG(lc.column_name, '|') WITHIN GROUP (ORDER BY lc.column_name)
             FROM   all_tab_columns lc
             WHERE  lc.owner = at.owner AND lc.table_name = at.table_name
             AND    lc.column_name IN
                    ('PROPOSAL_ID','PROPOSAL_NUMBER','AWARD_ID','AWARD_NUMBER',
                     'SEQUENCE_NUMBER','DOCUMENT_NUMBER','SUBAWARD_ID','SUBAWARD_CODE',
                     'NEGOTIATION_ID','SPONSOR_CODE','PRIME_SPONSOR_CODE','UNIT_NUMBER',
                     'LEAD_UNIT_NUMBER','PERSON_ID','ROLODEX_ID') )     AS lineage_keys
    FROM   all_tables at
    WHERE  at.owner = k_owner
    AND    (   at.table_name LIKE 'EPS_PROP%'   OR at.table_name LIKE 'NARRATIVE%'
           OR  at.table_name LIKE 'PROP_PERSON%' OR at.table_name LIKE 'INSTITUTIONAL_PROP%'
           OR  at.table_name LIKE 'INST_PROP%'  OR at.table_name LIKE 'AWARD%'
           OR  at.table_name LIKE 'SUBAWARD%'   OR at.table_name LIKE 'NEGOTIATION%'
           OR  at.table_name LIKE 'BUDGET%'
           OR  at.table_name IN ('SPONSOR','SPONSOR_HIERARCHY','ROLODEX','UNIT',
                                 'RATE_TYPE','SCIENCE_KEYWORD','NSF_CODE')
           OR  at.table_name LIKE '%_STATUS'    OR at.table_name LIKE '%_TYPE'
           OR  at.table_name LIKE 'CUSTOM_ATTRIBUTE%' OR at.table_name LIKE '%_CUSTOM_DATA'
           )
    ORDER  BY at.table_name
  ) LOOP

    -- Extract type: FULL for reference/master/lookup; SAMPLE for everything else.
    IF t.table_name IN ('SPONSOR','SPONSOR_HIERARCHY','UNIT','RATE_TYPE',
                        'SCIENCE_KEYWORD','NSF_CODE')
       OR t.table_name LIKE '%_STATUS'
       OR t.table_name LIKE '%_TYPE'
       OR t.table_name LIKE 'CUSTOM_ATTRIBUTE%'   -- definitions, not values
    THEN
      v_type := 'FULL';
    ELSE
      v_type := 'SAMPLE';                          -- transactional/history/custom-data/PII
    END IF;

    -- Domain + destination folder.
    IF    t.table_name LIKE 'AWARD%'                             THEN v_domain := 'award';
    ELSIF t.table_name LIKE 'SUBAWARD%'                          THEN v_domain := 'subaward';
    ELSIF t.table_name LIKE 'NEGOTIATION%'                       THEN v_domain := 'negotiation';
    ELSIF t.table_name LIKE 'BUDGET%'                            THEN v_domain := 'award';       -- budget shipped under award
    ELSIF t.table_name LIKE 'EPS_PROP%'
       OR t.table_name LIKE 'NARRATIVE%'
       OR t.table_name LIKE 'PROP_PERSON%'
       OR t.table_name LIKE 'INSTITUTIONAL_PROP%'
       OR t.table_name LIKE 'INST_PROP%'                         THEN v_domain := 'proposal';
    ELSE                                                              v_domain := 'reference';
    END IF;

    v_folder := CASE WHEN v_type = 'FULL' THEN 'reference' ELSE v_domain END;

    -- Exact row count of the SOURCE table (staging). Sample files will be <= this.
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || k_owner || '.' || t.table_name INTO v_cnt;

    DBMS_OUTPUT.PUT_LINE(
      v_domain                                  || ',' ||
      t.table_name                              || ',' ||
      v_type                                    || ',' ||
      v_folder || '/' || LOWER(t.table_name) || '.csv' || ',' ||
      NVL(t.pk_cols, '')                        || ',' ||
      NVL(t.lineage_keys, '')                   || ',' ||
      v_cnt                                     || ',' ||
      CASE v_type
        WHEN 'FULL'   THEN 'complete population'
        ELSE 'representative sample; all columns + lineage keys retained'
      END );
  END LOOP;
END;
/

SET FEEDBACK ON
