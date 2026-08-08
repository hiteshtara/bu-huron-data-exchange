# Institutional Proposal

**Status: COMPLETE** — pending review

Root object `org.kuali.kra.institutionalproposal.home.InstitutionalProposal` →
`KCOEUS.PROPOSAL`.

## Contents

| File | What it is |
|---|---|
| `PROPOSAL_GRAPH.md` | The object graph explained, with the findings that shaped it |
| `PROPOSAL_GRAPH.csv` | 64 relationships, machine readable |
| `PROPOSAL_FRONTEND_DATABASE_MAPPING.csv` | 138 UI fields traced to Oracle columns |
| `sql/` | Read-only Huron interface: root + 17 child collections |
| `sql/json/` | Nested JSON proof of concept (one proposal) |

## Root class

`PROPOSAL` is mapped by **two** OJB classes. `InstitutionalProposal` is the business
object: 53 fields, 11 references, **15 collections**, and the only one with a
DataDictionary entry. `InstitutionalProposalBoLite` is a lightweight projection
(22 fields, 1 collection, no DataDictionary) used only by `AwardFundingProposal`,
`AwardDocument` and the Elasticsearch serializers. Deriving the graph from `BoLite`
would have missed 14 of 15 collections.

## Population rule — the inverse of Award

`MAX(SEQUENCE_NUMBER)` is *unique* here (36,863 / 36,863, zero duplicates) but selects
the **wrong** version: for 80 proposals the ACTIVE row is not the highest sequence, and
the higher row is `CANCELED` (66), `PENDING` (10) or `ARCHIVED` (3).
`PROPOSAL_SEQUENCE_STATUS = 'ACTIVE'` is semantically right but not unique — 52
proposals have none and 1 has two.

Selector: prefer ACTIVE → highest sequence → highest `PROPOSAL_ID`. Exactly
**36,863 rows for 36,863 proposal numbers** (36,811 by ACTIVE, 52 by fallback).
See `sql/huron_proposal_latest_version_validation.sql`.

## Traps found

- **`PROPOSAL_EXTENSION` was mis-typed `MANY_TO_ONE`** because BU's fork declares
  `table="PROPOSAL_EXTENSION "` with a **trailing space** — the only such typo in the
  source. Production proves 1:1 optional (122,360 / 122,360 distinct, 0 orphans).
- **`PROPOSAL_LOG.INST_PROPOSAL_NUMBER` looks like the link and is not.** It is a
  7-character legacy identifier matching **zero** proposals. The real link is the shared
  `PROPOSAL_NUMBER`.
- **`EPS_PROP_PERSON_ROLE` doubles personnel** if joined unfiltered — 147,795 → 295,590
  rows. Pinned to the `DEFAULT` sponsor hierarchy.
- **`IP_REVIEW` is a separate versioned object**, not a child — reached through
  `PROPOSAL_IP_REVIEW_JOIN`, exactly one per proposal version.

## Verification

| Check | Result |
|---|---|
| SQL files executing against production | 19/19 |
| Row-preservation tests | 9/9 exact — no multiplication |
| Mapped columns verified in production | 83/83 |
| UI fields with a source-supported label | 131 of 138 |

## Regenerate

```bash
python scripts/build_object_graph.py --module proposal --source ~/…/kuali-research-bu-master \
    --row-counts <counts.csv> --output modules/proposal/PROPOSAL_GRAPH.csv
python scripts/build_frontend_mapping.py --module proposal --source ~/…/kuali-research-bu-master \
    --dictionary reference/KUALI_FIELD_DICTIONARY.csv --custom-attributes <catalog.csv> \
    --prod-columns <columns.csv> --output modules/proposal/PROPOSAL_FRONTEND_DATABASE_MAPPING.csv
```
