/*
Purpose:     Extract KC PROPOSAL data (Proposal Development + Institutional Proposal) for Huron.
Module:      Proposal
Environment: KC / Oracle (read-only)
Target:      CSV -> bu_grants_dump_for_huron/proposal/*.csv
Author:      BU Huron Data Exchange
Date:        2026-08-07

Business rule:
  Fields over rows. Extract a representative SAMPLE per table (first N rows) — enough for the
  AI tool to learn column meaning and value formats. Preserve lineage keys: proposal_id,
  proposal_number, sequence_number, document_number.

Validation:
  Row counts -> 02_table_manifest.csv. Confirm sponsor_code / unit_number / status codes all
  resolve against grants_common_reference_extract.sql.

Object names are CONFIRMED against the KCOEUS staging schema discovery (2026-08-07).
EXTRACT_TYPE = SAMPLE: representative rows only — SELECT * keeps ALL columns and lineage keys;
only the row count is reduced. This is a field-discovery sample, not a final population.
Adjust the sample size (1000) to what Huron prefers.
*/

-- Proposal Development (pre-award, in-progress) ------------------------------
SELECT * FROM eps_proposal              FETCH FIRST 1000 ROWS ONLY;  -- proposal dev header
SELECT * FROM eps_prop_person           FETCH FIRST 1000 ROWS ONLY;  -- PI / Co-I / key persons
SELECT * FROM eps_prop_person_unit      FETCH FIRST 1000 ROWS ONLY;  -- person -> unit
SELECT * FROM eps_prop_person_credit_split FETCH FIRST 1000 ROWS ONLY; -- credit allocation
SELECT * FROM eps_prop_special_review   FETCH FIRST 1000 ROWS ONLY;  -- IRB/IACUC linkage
SELECT * FROM eps_prop_science_keyword  FETCH FIRST 1000 ROWS ONLY;
SELECT * FROM narrative                 FETCH FIRST 1000 ROWS ONLY;  -- attachment metadata
-- Proposal custom-field values (BU extended fields):
SELECT * FROM eps_prop_custom_data      FETCH FIRST 1000 ROWS ONLY;  -- VERIFY name

-- Institutional Proposal (proposal of record) -------------------------------
SELECT * FROM institutional_proposal        FETCH FIRST 1000 ROWS ONLY;  -- IP header
SELECT * FROM inst_prop_person              FETCH FIRST 1000 ROWS ONLY;
SELECT * FROM inst_prop_person_unit         FETCH FIRST 1000 ROWS ONLY;
SELECT * FROM inst_prop_person_credit_split FETCH FIRST 1000 ROWS ONLY;
SELECT * FROM inst_prop_amount_info         FETCH FIRST 1000 ROWS ONLY;  -- $ by line
SELECT * FROM inst_prop_cost_share          FETCH FIRST 1000 ROWS ONLY;
SELECT * FROM inst_prop_special_review      FETCH FIRST 1000 ROWS ONLY;
SELECT * FROM inst_prop_science_keyword     FETCH FIRST 1000 ROWS ONLY;
SELECT * FROM inst_prop_custom_data         FETCH FIRST 1000 ROWS ONLY;  -- VERIFY name

-- Proposal budget (shared budget tables scoped to proposal docs) -------------
-- Budget tables (BUDGET / BUDGET_PERIOD / BUDGET_DETAILS / BUDGET_PERSONNEL_DETAILS) are shared
-- by proposal and award. Extract the sample once (see grants_award_extract.sql budget section)
-- and note in the manifest which parent (proposal vs award) each budget belongs to.
