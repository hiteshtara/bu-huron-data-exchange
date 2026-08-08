/*
Purpose:     Extract KC SUBAWARD and NEGOTIATION data for Huron.
Module:      Subaward, Negotiations
Environment: KC / Oracle (read-only)
Target:      CSV -> bu_grants_dump_for_huron/subaward/*.csv , /negotiation/*.csv
Author:      BU Huron Data Exchange
Date:        2026-08-07

Business rule:
  Fields over rows; representative sample per table. Preserve lineage: subaward_id / subaward_code,
  and the funding-source link back to award_id / award_number. For negotiations preserve
  negotiation_id and its association back to proposal/award.

Validation:
  Row counts -> 02_table_manifest.csv. Confirm subaward_funding_source.award_id resolves to an
  award in the award extract; confirm negotiation associations resolve to a proposal/award.

Object names are CONFIRMED against the KCOEUS staging schema discovery (2026-08-07).
EXTRACT_TYPE = SAMPLE: representative rows only — SELECT * keeps ALL columns and lineage keys
(subaward_id, award_id, negotiation_id); only the row count is reduced. Field-discovery sample,
not a final population.
*/

-- Subaward (outgoing subawards) ---------------------------------------------
SELECT * FROM subaward                  FETCH FIRST 1000 ROWS ONLY;  -- header
SELECT * FROM subaward_amount_info      FETCH FIRST 1000 ROWS ONLY;  -- obligated/anticipated $
SELECT * FROM subaward_amount_released  FETCH FIRST 1000 ROWS ONLY;  -- releases (VERIFY name)
SELECT * FROM subaward_funding_source   FETCH FIRST 1000 ROWS ONLY;  -- link to award
SELECT * FROM subaward_contact          FETCH FIRST 1000 ROWS ONLY;  -- contacts (PII sample only)
SELECT * FROM subaward_closeout         FETCH FIRST 1000 ROWS ONLY;  -- closeout items
-- Subaward custom-field values:
SELECT * FROM subaward_custom_data      FETCH FIRST 1000 ROWS ONLY;  -- VERIFY name

-- Negotiation ---------------------------------------------------------------
SELECT * FROM negotiation               FETCH FIRST 1000 ROWS ONLY;  -- header
SELECT * FROM negotiation_activity      FETCH FIRST 1000 ROWS ONLY;  -- activity log
SELECT * FROM negotiation_location      FETCH FIRST 1000 ROWS ONLY;  -- current location/owner
SELECT * FROM negotiation_association   FETCH FIRST 1000 ROWS ONLY;  -- link to proposal/award
-- Negotiation custom-field values (if BU uses them):
SELECT * FROM negotiation_custom_data   FETCH FIRST 1000 ROWS ONLY;  -- VERIFY name
