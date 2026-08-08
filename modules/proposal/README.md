# Institutional Proposal

**Status: IN PROGRESS**

Root object `org.kuali.kra.institutionalproposal.home.InstitutionalProposal` →
`KCOEUS.PROPOSAL`.

## Contents

| File | What it is |
|---|---|
| `PROPOSAL_GRAPH.csv` | 33 relationships discovered so far (work in progress) |
| `sql/huron_proposal_latest_version_validation.sql` | Population rule, validated |

## Root class

`PROPOSAL` is mapped by **two** OJB classes. `InstitutionalProposal` is the real
business object: 53 fields, 11 references, 15 collections, and the only one with a
DataDictionary entry. `InstitutionalProposalBoLite` is a lightweight projection
(22 fields, 1 collection, no DataDictionary) used only where an Award or the search
index needs to reference a proposal without loading the full graph.

## Population rule

The inverse of Award, so Award's selector was **not** reused unchanged:

- `MAX(SEQUENCE_NUMBER)` is structurally unique here — 36,863 rows for 36,863
  proposal numbers, zero duplicates — but selects the **wrong** version: for 80
  proposals the ACTIVE row is not the highest sequence, and the higher row is
  `CANCELED` (66), `PENDING` (10) or `ARCHIVED` (3).
- `PROPOSAL_SEQUENCE_STATUS = 'ACTIVE'` is semantically correct but not unique:
  36,810 proposals have one ACTIVE row, 52 have none, and 1 has two.

Selector: prefer ACTIVE → highest sequence → highest `PROPOSAL_ID`. Returns exactly
36,863 rows for 36,863 proposal numbers (36,811 by ACTIVE, 52 by fallback).

## Still to do

Graph completion (service-layer relationships, personnel sub-graph), front-end field
mapping, `PROPOSAL_EXTENSION` profiling, INPR custom attributes, SQL interface,
row-preservation tests, JSON proof of concept.
