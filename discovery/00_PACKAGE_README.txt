================================================================================
BU GRANTS DATA DUMP FOR HURON - FIELD DISCOVERY & AI MAPPING
================================================================================

Prepared by : Boston University - Huron Data Exchange team
Source      : Kuali Coeus (KC) on Oracle - KCOEUS PRODUCTION schema
              host prod.db.kuali.research.bu.edu, database KUALI
Extract date: 2026-08-07
KC version  : BU fork, application branch bu-master
Contact     : <name / email>

--------------------------------------------------------------------------------
1. PURPOSE  (please read first)
--------------------------------------------------------------------------------
This package is provided so Huron can run its AI mapping tooling to discover and
map BU's KC Grants FIELDS to HRS v12 Grants.

It is a FIELD-DISCOVERY and MAPPING package. It is:

  * NOT a final migration extract.
  * NOT cleansed to final data-quality standards.
  * NOT the final population selection for conversion.

Row samples are representative, not complete. The goal (per Phil's note) is
FIELDS over ROWS: complete column coverage with clearly-defined headers, plus
enough real values for the tooling to infer meaning. Final population selection,
cleansing, and reconciliation happen later, during the migration itself.

Data anomalies noticed during discovery are REPORTED, not fixed. See section 9.

--------------------------------------------------------------------------------
2. SOURCE OBJECT NAMES - CONFIRMED FROM PRODUCTION
--------------------------------------------------------------------------------
All table and column names here were CONFIRMED from live BU KCOEUS PRODUCTION
metadata (ALL_TABLES / ALL_TAB_COLUMNS / ALL_CONSTRAINTS) on the extract date.
Row counts are actual COUNT(*) values, not optimiser statistics.

Access was READ ONLY throughout, through a controlled runner that sets
SET TRANSACTION READ ONLY and permits only SELECT/WITH statements. No DML or DDL
was executed against production at any point.

--------------------------------------------------------------------------------
3. START HERE - THE FIELD DICTIONARY
--------------------------------------------------------------------------------
IMPORTANT: Kuali Coeus stores NO column comments in Oracle. Zero. The database
alone cannot tell you what a column means.

The business meaning lives in the Kuali application's DataDictionary. We have
extracted it and shipped it as:

  KUALI_FIELD_DICTIONARY.csv

which chains every field end to end:

  Oracle table/column -> Java object/property -> Kuali UI label
                      -> lookup/reference object -> BU custom attribute
                      -> mapping priority

Key columns:

  UI_FIELD_NAME     The label BU users actually see on the Kuali screen.
                    Populated ONLY where a DataDictionary label could be
                    resolved from the Kuali source. Never guessed. Blank means
                    "not asserted", not "no label exists".

  FIELD_ORIGIN      CORE_KUALI          stock KC field
                    LOOKUP_REFERENCE    field on a reference/code table
                    BU_EXTENSION        BU extension table column
                    BU_CUSTOM_ATTRIBUTE BU-configured custom field

  MAPPING_PRIORITY  HIGH / MEDIUM / LOW / NOT_FOR_HURON
                    Use this to focus on business fields. NOT_FOR_HURON marks
                    technical columns (OBJ_ID, VER_NBR, UPDATE_TIMESTAMP,
                    UPDATE_USER) that carry no business meaning.

  CONFIDENCE        HIGH   column verified in production AND a UI label resolved
                    MEDIUM column verified, ORM mapping only (no label)
                    LOW    table/column not found in production

Do NOT assume a Java property name equals the UI label. For example
AWARD.AWARD_NUMBER has Java property awardNumber but the screen label is
"Award ID"; PROPOSAL.TITLE is shown as "Project Title".

--------------------------------------------------------------------------------
4. BU CUSTOM FIELDS - READ THIS BEFORE USING *_CUSTOM_DATA
--------------------------------------------------------------------------------
BU's custom fields use KC's custom-attribute definition/value model. The physical
tables are EAV-style value stores:

  CUSTOM_ATTRIBUTE                 (definition: ID, NAME, LABEL, GROUP_NAME,
                                    DATA_TYPE_CODE, DATA_LENGTH, ...)
        1
        |  CUSTOM_ATTRIBUTE_ID
        many
  AWARD_CUSTOM_DATA        (AWARD_ID, AWARD_NUMBER, SEQUENCE_NUMBER,
                            CUSTOM_ATTRIBUTE_ID, VALUE)
  PROPOSAL_CUSTOM_DATA     (PROPOSAL_ID, PROPOSAL_NUMBER, SEQUENCE_NUMBER,
                            CUSTOM_ATTRIBUTE_ID, VALUE)
  SUBAWARD_CUSTOM_DATA     (SUBAWARD_ID, SUBAWARD_CODE, SEQUENCE_NUMBER,
                            CUSTOM_ATTRIBUTE_ID, VALUE)
  NEGOTIATION_CUSTOM_DATA  (NEGOTIATION_ID, NEGOTIATION_NUMBER,
                            CUSTOM_ATTRIBUTE_ID, VALUE)

A row such as

  PROPOSAL_NUMBER=..., CUSTOM_ATTRIBUTE_ID=1542, VALUE='Yes'

does NOT represent a field called "VALUE". The business field is whatever
custom attribute 1542 is defined to be. VALUE is merely the generic storage
location; CUSTOM_ATTRIBUTE_ID is the field identity.

You should not have to resolve this yourself. We have already done it:

  custom_fields/<module>_custom_data_normalized.csv
      EAV rows with the definition joined on - module, record number, record id,
      sequence number, attribute id, attribute NAME, attribute LABEL, group,
      data type, and the value. Keeps full lineage.

  custom_fields/<module>_custom_fields_wide.csv
      The same data PIVOTED: one row per record, one NAMED COLUMN per custom
      field. This is the mapping-friendly form - map against these column names.

  custom_fields/<module>_custom_fields_wide_columns.csv
      Header dictionary for the pivot: every generated column mapped back to its
      CUSTOM_ATTRIBUTE_ID, name, label, group, data type, and length.

BU has 107 configured custom attributes. Module applicability comes from
CUSTOM_ATTRIBUTE_DOCUMENT.DOCUMENT_TYPE_CODE (authoritative configuration), NOT
from the presence of a value:

  AWRD  Award                    46
  INPR  Institutional Proposal   45
  SAWD  Subaward                 15
  NGT   Negotiation               8
  PRDV  Proposal Development      4
  PROT  Protocol / IRB           28   (out of Grants scope)
  (none) not attached             3   (see section 9)

--------------------------------------------------------------------------------
5. EXTRACT STRATEGY  (how each table was pulled)
--------------------------------------------------------------------------------
Marked per table in 02_table_manifest.csv (EXTRACT_TYPE):

  FULL    164 tables. Reference / master / lookup tables at or below 20,000 rows
          (sponsors, units, organizations, statuses, types, rate types,
          custom-attribute definitions). Exported as the COMPLETE population so
          every coded value in the transactional files is decodable.

  SAMPLE   76 tables. Large transactional / history / custom-data tables.
          Exported as a REPRESENTATIVE sample of ~1,000 rows, spread across the
          whole table using ROW_NUMBER() OVER (ORDER BY ROWID) with a modulo
          step - NOT the physically-first rows.
          IMPORTANT: samples retain ALL COLUMNS and ALL LINEAGE KEYS
          (award_id, award_number, proposal_id, proposal_number, subaward_id,
          subaward_code, negotiation_id, sequence_number, document_number,
          sponsor_code, unit_number, organization_id).
          Only the row COUNT is reduced - never the column set.

  EMPTY   119 tables. Zero rows in production. Their COLUMNS are still fully
          documented in 01_data_dictionary.csv (fields matter more than rows),
          but no data file is produced. An empty table generally means BU does
          not use that KC feature - useful mapping signal in itself.

--------------------------------------------------------------------------------
6. FILE FORMAT / CONVENTIONS
--------------------------------------------------------------------------------
  * Encoding      : UTF-8
  * Delimiter     : comma (,)
  * Quoting       : double-quote ("), doubled to escape embedded quotes
  * Header row    : row 1, using the ACTUAL KC column names (not renamed)
  * Dates         : ISO format YYYY-MM-DD HH24:MI:SS
  * NULL          : empty field (no literal "NULL" text)
  * Line endings  : LF
  * CLOB columns  : truncated to the first 1,000 characters
  * BLOB columns  : replaced by the byte length of the stored file

--------------------------------------------------------------------------------
7. PACKAGE CONTENTS
--------------------------------------------------------------------------------
  00_README.txt              This file.
  01_data_dictionary.csv     All 4,074 in-scope columns: table, column, datatype,
                             nullability, default, plus UI_FIELD_NAME,
                             JAVA_OBJECT/PROPERTY, LOOKUP_TABLE/COLUMN,
                             FIELD_ORIGIN and MAPPING_PRIORITY.
                             THE authority for headers.
  02_table_manifest.csv      One row per in-scope table (359): domain, extract
                             type, row count, column count, primary key,
                             lineage keys, PII flag.
  02_excluded_tables.csv     One row per excluded table (542) with a reason code.
  02_extract_log.csv         Per-table extract result and rows written.
  KUALI_FIELD_DICTIONARY.csv The end-to-end field trace (see section 3).

  award/                     Award, amounts, terms, hierarchy, time & money.
  institutional_proposal/    Institutional Proposals and IP review.
  proposal/                  Proposal Development, budgets, narratives, S2S.
  subaward/                  Subawards, amounts, funding sources, contacts.
  negotiation/               Negotiations and activities.
  reference/                 Sponsors, organizations, units, lookups (FULL).
  bu_custom/                 Custom-attribute definitions and raw EAV tables.
  custom_fields/             Normalized + pivoted BU custom fields (section 4).

--------------------------------------------------------------------------------
8. PII / DATA HANDLING
--------------------------------------------------------------------------------
Person and external-contact data (rolodex, person, contact tables) is included as
COLUMN STRUCTURE with a small sample only (100 rows rather than 1,000).

Within those tables, name / email / phone / address columns and any
SSN, date-of-birth, citizenship, gender, race, disability, veteran or salary
column are emitted as the literal text REDACTED. The COLUMN IS RETAINED so the
field structure is visible - only the personal value is withheld.

The tooling needs the field structure, not the person population. If Huron needs
un-masked values for a specific field, request it and BU will route it through
data governance.

No credentials, connection strings, API tokens, or keys appear in this package.

--------------------------------------------------------------------------------
9. KNOWN ANOMALIES - REPORTED, NOT FIXED
--------------------------------------------------------------------------------
Per the scope of this exercise these are flagged for discussion, not corrected:

  1. Proposal Development appears unused at BU: EPS_PROPOSAL holds 1 row, while
     PROPOSAL (Institutional Proposal) holds 130,121.

  2. BUDGET (80,248 rows) is used for AWARD budgets via AWARD_BUDGET_EXT
     (80,145). However EPS_PROP_RATES holds 1,895,754 rows despite Proposal
     Development being empty - ownership of those rate rows needs confirming.

  3. Custom attribute 1212 "Contract" is attached to NO document type, yet has
     values in both AWARD_CUSTOM_DATA and PROPOSAL_CUSTOM_DATA. Two further
     attributes are similarly unattached.

  4. Custom attribute 1213 "Billing Agreement" is attached only to AWRD but has
     values in PROPOSAL_CUSTOM_DATA.

  5. Some custom attributes have value rows in which every value is NULL. These
     are flagged in the NOTES column of KUALI_FIELD_DICTIONARY.csv.

--------------------------------------------------------------------------------
10. HOW TO USE
--------------------------------------------------------------------------------
  1. Start with KUALI_FIELD_DICTIONARY.csv. Filter MAPPING_PRIORITY = HIGH to see
     the business fields first; ignore NOT_FOR_HURON.
  2. Use 01_data_dictionary.csv for the full column inventory and headers.
  3. Use 02_table_manifest.csv to see each file's domain, grain, extract type,
     keys, and PII flag.
  4. For BU custom fields, map against custom_fields/*_custom_fields_wide.csv
     (named columns), not the raw *_CUSTOM_DATA EAV tables.
  5. Join transactional samples to reference/ files by code columns to decode
     values (e.g. AWARD.SPONSOR_CODE -> reference/sponsor.csv). The
     LOOKUP_TABLE / LOOKUP_COLUMN columns of the field dictionary tell you which
     reference object decodes each coded field.
  6. Treat every row count as a SAMPLE unless EXTRACT_TYPE = FULL.
================================================================================
