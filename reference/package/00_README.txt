================================================================================
BU GRANTS DATA DUMP FOR HURON — FIELD DISCOVERY & AI MAPPING
================================================================================

Prepared by : Boston University — Huron Data Exchange team
Source      : Kuali Coeus (KC) on Oracle — KCOEUS staging schema
Extract date: <YYYY-MM-DD>
KC version  : <fill in>
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

--------------------------------------------------------------------------------
2. SOURCE OBJECT NAMES — CONFIRMED
--------------------------------------------------------------------------------
All source table and column names in this package were CONFIRMED from the BU
KCOEUS staging schema via schema discovery (see 01_data_dictionary.csv). They are
not assumed — the data dictionary is generated directly from the live staging
schema and is the authority for every header in every file.

--------------------------------------------------------------------------------
3. EXTRACT STRATEGY  (how each table was pulled)
--------------------------------------------------------------------------------
Two extract types, marked per file in 02_table_manifest.csv (EXTRACT_TYPE):

  FULL    Reference / master / lookup tables. Small and code-defining
          (sponsors, units, statuses, types, rate types, custom-attribute
          definitions). Exported as the COMPLETE population so every coded value
          in the transactional files is decodable.

  SAMPLE  Large transactional / history / custom-data tables (proposals, awards,
          subawards, negotiations, budgets, *_custom_data, and PII-bearing
          contact tables). Exported as a REPRESENTATIVE sample.
          IMPORTANT: samples retain ALL COLUMNS and ALL LINEAGE KEYS
          (proposal_id, proposal_number, award_id, award_number, sequence_number,
          document_number, subaward_id, sponsor_code, unit_number, person/rolodex id).
          Only the row COUNT is reduced — never the column set.

--------------------------------------------------------------------------------
4. FILE FORMAT / CONVENTIONS
--------------------------------------------------------------------------------
  * Encoding      : UTF-8
  * Delimiter     : comma (,)
  * Quoting       : double-quote ("), doubled to escape embedded quotes
  * Header row    : row 1, using the ACTUAL KC column names (not renamed)
  * Dates         : ISO format YYYY-MM-DD (time component YYYY-MM-DD HH24:MI:SS)
  * NULL          : empty field (no literal "NULL" text)
  * Line endings  : LF

--------------------------------------------------------------------------------
5. PACKAGE CONTENTS
--------------------------------------------------------------------------------
  00_README.txt              This file.
  01_data_dictionary.csv     Every in-scope table/column: name, datatype,
                             nullability, default, comment. Generated from the
                             KCOEUS staging schema. THE authority for headers.
  02_table_manifest.csv      One row per data file: domain, table, grain,
                             extract type (FULL/SAMPLE), row count, key columns.
  reference/                 FULL reference/master/lookup extracts.
  proposal/                  SAMPLE — Proposal Development + Institutional Proposal.
  award/                     SAMPLE — Awards, amounts, terms, hierarchy, budget.
  subaward/                  SAMPLE — Subawards and funding sources.
  negotiation/               SAMPLE — Negotiations and activities.

--------------------------------------------------------------------------------
6. PII / DATA HANDLING
--------------------------------------------------------------------------------
Person and external-contact data (rolodex / KIM entity / contact tables) is
included as COLUMN STRUCTURE with a small representative sample only; sensitive
values (e.g. SSN, DOB, home address) are masked or tokenized. The tooling needs
the field structure, not the person population. If Huron needs un-masked values
for a specific field, request it and BU will route it through data governance.

--------------------------------------------------------------------------------
7. HOW TO USE
--------------------------------------------------------------------------------
  1. Start with 01_data_dictionary.csv for the full field inventory + headers.
  2. Use 02_table_manifest.csv to see each file's grain, extract type, and keys.
  3. Join transactional samples to reference/ files by code columns to decode
     values (e.g. AWARD.SPONSOR_CODE -> reference/sponsor.csv).
  4. Treat every row count as a SAMPLE unless EXTRACT_TYPE = FULL.
================================================================================
