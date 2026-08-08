/*
Purpose:     Extract KC Grants COMMON / REFERENCE tables (dimensions + lookups) for Huron.
Module:      Common
Environment: KC / Oracle (read-only)
Source:      KC common/reference tables
Target:      CSV -> bu_grants_dump_for_huron/reference/*.csv
Author:      BU Huron Data Exchange
Date:        2026-08-07

Business rule:
  Reference/lookup tables are small and decode the coded values in every other extract
  (status codes, type codes, sponsor codes, unit numbers, custom-field definitions).
  Extract these in FULL — they are what let the AI mapping tool interpret codes correctly.

Validation:
  Each extract's row count -> 02_table_manifest.csv.
  Confirm every code column referenced in module extracts has its lookup table here.

Object names are CONFIRMED against the KCOEUS staging schema discovery (2026-08-07).
EXTRACT_TYPE = FULL here: these are small reference/master/lookup tables — export the
COMPLETE population so coded values in the transactional samples are decodable.
Exception: ROLODEX is PII-bearing and is SAMPLED + masked (see below), not full.
*/

-- Dimensions (FULL population) ----------------------------------------------
-- Sponsor: sponsor_code, sponsor_name, sponsor_type_code, ...
SELECT * FROM sponsor;                    -- decode SPONSOR_CODE / PRIME_SPONSOR_CODE
SELECT * FROM sponsor_hierarchy;          -- sponsor groupings

-- Unit hierarchy: unit_number, unit_name, parent_unit_number
SELECT * FROM unit;                       -- decode LEAD_UNIT_NUMBER / unit_number

-- Rolodex: external contacts (rolodex_id, organization, address, ...)
-- PII — SAMPLE + mask sensitive values; keep all columns + rolodex_id lineage key.
SELECT * FROM rolodex FETCH FIRST 1000 ROWS ONLY;

-- Rate types / F&A + fringe rate tables (names vary: RATE_TYPE, INSTITUTE_RATE, ...)
SELECT * FROM rate_type;

-- Science / keyword + NSF discipline codes
SELECT * FROM science_keyword;
SELECT * FROM nsf_code;

-- Lookups (FULL population) -------------------------------------------------
-- KC stores valid values in many small *_STATUS and *_TYPE tables. Enumerate the
-- actual set from discovery, then extract each. Common ones:
SELECT * FROM proposal_status;
SELECT * FROM proposal_type;
SELECT * FROM award_status;
SELECT * FROM activity_type;              -- award/proposal activity type
SELECT * FROM award_type;                 -- if present in BU instance

-- Custom attributes (BU-added fields) — HIGH VALUE for mapping ---------------
-- CUSTOM_ATTRIBUTE defines the field; *_CUSTOM_DATA holds values per record.
-- Send the DEFINITIONS in full so Huron sees BU's extended fields explicitly.
SELECT * FROM custom_attribute;           -- id, name, label, data_type, lookup, group
SELECT * FROM custom_attribute_document;  -- which document types use each attribute

/*
Person data note:
  KC person identity lives in Rice KIM tables (KRIM_ENTITY_T, KRIM_PRINCIPAL_T,
  KRIM_ENTITY_NM_T, KRIM_ENTITY_EMP_INFO_T, ...) and/or a KC_PERSON view. These carry
  names, emails, and possibly SSN/DOB. For AI mapping send COLUMN STRUCTURE + a small,
  PII-masked sample only. Do NOT bulk-export the person population. See the redaction
  section in reference/GRANTS_DATA_DUMP_FOR_HURON.md.
*/
