# Institutional Proposal

Status: **Technical mapping complete · BU validation pending**

The graph, field mapping and SQL are built and verified against production. That is
not the same as the business decisions being settled — see
[the decision register](../../docs/DECISION_REGISTER.md) for what is still open, and
[the Huron review items](../../reference/HURON_REVIEW_ITEMS.md) for the subset we want to
work through with Huron.
Counts measured 2026-08-07 ([provenance](../../docs/PROVENANCE.md)).

Root is `org.kuali.kra.institutionalproposal.home.InstitutionalProposal` →
`KCOEUS.PROPOSAL`.

## What's in here

| File | What it is |
|---|---|
| `PROPOSAL_GRAPH.md` | The graph, and what we found working it out |
| `PROPOSAL_GRAPH.csv` | 64 relationships, machine readable |
| `PROPOSAL_FRONTEND_DATABASE_MAPPING.csv` | 138 UI fields traced to Oracle columns |
| `sql/` | Root plus 16 child collections, read only |
| `sql/json/` | Nested JSON proof of concept for one proposal |

## Two classes map to PROPOSAL, and only one is the business object

`InstitutionalProposal` has 53 fields, 11 references, 15 collections, and the
DataDictionary entry. `InstitutionalProposalBoLite` has 22 fields, 1 collection and no
DataDictionary — it is a lightweight projection used by `AwardFundingProposal`,
`AwardDocument` and the search index when something needs to mention a proposal without
loading its whole graph.

Worth knowing because if you build the graph from `BoLite` you lose 14 of the 15
collections.

## How we pick the current Proposal

This one is the opposite of Award, so we did not reuse Award's rule.

`MAX(SEQUENCE_NUMBER)` is perfectly unique here — 36,863 rows for 36,863 proposal
numbers, no duplicates at all. But it picks the wrong row. For 80 proposals the ACTIVE
row is not the highest sequence, and the row above it is `CANCELED` (66), `PENDING` (10)
or `ARCHIVED` (3). Sorting by sequence would hand Huron cancelled and in-progress
versions as the record of record.

`PROPOSAL_SEQUENCE_STATUS = 'ACTIVE'` is the right marker but is not unique on its own:
36,810 proposals have exactly one ACTIVE row, 52 have none, and 1 has two.

So we prefer ACTIVE, then take the highest sequence, then the highest `PROPOSAL_ID`.
That gives exactly 36,863 rows for 36,863 proposal numbers — 36,811 from the ACTIVE
branch and 52 from the fallback. `sql/huron_proposal_latest_version_validation.sql` has
the counts.

## Things that would be easy to get wrong

**`PROPOSAL_EXTENSION` looked like the wrong kind of relationship.** Our graph builder
first typed it `MANY_TO_ONE`, and the reason turned out to be a typo: BU's fork declares
`table="PROPOSAL_EXTENSION "` with a trailing space, the only one like it in the whole
source. Every lookup keyed on table name missed. Production says it is an optional 1:1 —
122,360 rows, 122,360 distinct `PROPOSAL_ID`, no orphans, and 7,762 proposals with no
extension row.

**Do not join `PROPOSAL_LOG` on `INST_PROPOSAL_NUMBER`.** It looks like the link to the
Institutional Proposal and it is not. We tested all 30,646 populated values and none of
them match a `PROPOSAL.PROPOSAL_NUMBER`. It is a 7-character legacy identifier where
proposal numbers are 8 characters. The real link is the shared `PROPOSAL_NUMBER`.

**The person role lookup doubles the dataset** — the same `EPS_PROP_PERSON_ROLE` problem
as Award. Unfiltered it takes personnel from 147,795 rows to 295,590. We pin it to the
`DEFAULT` sponsor hierarchy.

**`IP_REVIEW` is its own business object**, not a child. It has its own sequence and its
own ACTIVE/ARCHIVED status, and you reach it through `PROPOSAL_IP_REVIEW_JOIN`. In
practice there is exactly one review per proposal version.

## Checks

| Check | Result |
|---|---|
| SQL files running against production | 19/19 |
| Row-preservation tests | 9/9 exact |
| Mapped columns verified in production | 83/83 |
| UI fields with a source-supported label | 131 of 138 |

## Regenerating

```bash
.venv/bin/python scripts/build_object_graph.py --module proposal --source ~/…/kuali-research-bu-master \
    --row-counts <counts.csv> --output modules/proposal/PROPOSAL_GRAPH.csv

.venv/bin/python scripts/build_frontend_mapping.py --module proposal --source ~/…/kuali-research-bu-master \
    --dictionary reference/KUALI_FIELD_DICTIONARY.csv --custom-attributes <catalog.csv> \
    --prod-columns <columns.csv> --output modules/proposal/PROPOSAL_FRONTEND_DATABASE_MAPPING.csv
```
