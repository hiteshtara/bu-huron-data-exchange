/*
Purpose:     Extract KC AWARD data (awards, amounts, terms, hierarchy, budget) for Huron.
Module:      Award
Environment: KC / Oracle (read-only)
Target:      CSV -> bu_grants_dump_for_huron/award/*.csv
Author:      BU Huron Data Exchange
Date:        2026-08-07

Business rule:
  Fields over rows. Awards are versioned in KC (award_number + sequence_number, with a
  sequence-status marking the active version). For a mapping sample the full version history is
  not required — a representative sample of rows is enough — but PRESERVE award_id, award_number,
  and sequence_number so version semantics are visible to the mapper.

Validation:
  Row counts -> 02_table_manifest.csv. Confirm sponsor_code / prime_sponsor_code / lead_unit
  resolve against reference extracts. Confirm award_funding_proposal links to a proposal_id
  present in the proposal extract.

Object names are CONFIRMED against the KCOEUS staging schema discovery (2026-08-07).
EXTRACT_TYPE = SAMPLE: representative rows only — SELECT * keeps ALL columns and lineage keys
(award_id, award_number, sequence_number); only the row count is reduced. Field-discovery
sample, not a final population.
*/

-- Award core ----------------------------------------------------------------
SELECT * FROM award                     FETCH FIRST 1000 ROWS ONLY;  -- header (versioned)
SELECT * FROM award_amount_info         FETCH FIRST 1000 ROWS ONLY;  -- obligated/anticipated $
SELECT * FROM award_person              FETCH FIRST 1000 ROWS ONLY;  -- PI / key persons
SELECT * FROM award_person_unit         FETCH FIRST 1000 ROWS ONLY;  -- person -> unit
SELECT * FROM award_person_credit_split FETCH FIRST 1000 ROWS ONLY;  -- credit allocation

-- Relationships / structure -------------------------------------------------
SELECT * FROM award_funding_proposal    FETCH FIRST 1000 ROWS ONLY;  -- award <-> IP/proposal
SELECT * FROM award_hierarchy           FETCH FIRST 1000 ROWS ONLY;  -- parent/root award tree

-- Terms, conditions, compliance ---------------------------------------------
SELECT * FROM award_sponsor_term        FETCH FIRST 1000 ROWS ONLY;
SELECT * FROM award_report_term         FETCH FIRST 1000 ROWS ONLY;  -- deliverables/reporting
SELECT * FROM award_special_review      FETCH FIRST 1000 ROWS ONLY;  -- IRB/IACUC linkage
SELECT * FROM award_cost_share          FETCH FIRST 1000 ROWS ONLY;
SELECT * FROM award_fanda_rate          FETCH FIRST 1000 ROWS ONLY;  -- F&A rates on award
SELECT * FROM award_keyword             FETCH FIRST 1000 ROWS ONLY;  -- science keywords
SELECT * FROM award_comment             FETCH FIRST 1000 ROWS ONLY;  -- narrative/comments

-- Award custom-field values (BU extended fields) ----------------------------
SELECT * FROM award_custom_data         FETCH FIRST 1000 ROWS ONLY;  -- VERIFY name

-- Budget (shared BUDGET* tables — sample once for the whole package) ---------
SELECT * FROM budget                    FETCH FIRST 1000 ROWS ONLY;  -- budget header
SELECT * FROM budget_period             FETCH FIRST 1000 ROWS ONLY;  -- periods
SELECT * FROM budget_details            FETCH FIRST 1000 ROWS ONLY;  -- line items
SELECT * FROM budget_personnel_details  FETCH FIRST 1000 ROWS ONLY;  -- personnel lines
