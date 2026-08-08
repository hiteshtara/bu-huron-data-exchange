# Negotiation

**Status: COMPLETE** — pending review

Root is `org.kuali.kra.negotiations.bo.Negotiation` → `KCOEUS.NEGOTIATION`. One class,
one DataDictionary entry, no projection variant.

## What's in here

| File | What it is |
|---|---|
| `NEGOTIATION_GRAPH.md` | The graph, and what we found working it out |
| `NEGOTIATION_GRAPH.csv` | 15 relationships, machine readable |
| `NEGOTIATION_FRONTEND_DATABASE_MAPPING.csv` | 46 UI fields traced to Oracle columns |
| `sql/` | Root plus 3 child collections, read only |
| `sql/json/` | Nested JSON proof of concept for one negotiation |

## The short version

**Negotiation is not versioned.** 11,842 rows, 11,842 distinct ids, and zero rows in
`VERSION_HISTORY` for the class. No `SEQUENCE_NUMBER`, no sequence status. One row is
one negotiation, so this module has no version selector at all — the only one of the
four that doesn't.

**`ASSOCIATED_DOCUMENT_ID` means four different things.** It points at
`AWARD.AWARD_NUMBER`, `SUBAWARD.SUBAWARD_CODE` or `PROPOSAL.PROPOSAL_NUMBER` depending on
the association type, or at nothing when the type is None. All 11,842 rows resolve
correctly against the parent their type implies. The root query spells this out in
`ASSOCIATED_DOCUMENT_ID_MEANS`.

**Most negotiations aren't attached to anything.** 9,249 of 11,842 (78%) have
association type None, and their real content lives in `NEGOTIATION_UNASSOC_DETAIL`,
which is 1:1 and folded into the root.

**Attachments belong to activities, not to the negotiation.** The attachment dataset
joins back through `NEGOTIATION_ACTIVITY` so every row still carries its
`NEGOTIATION_ID`.

**No BU extension table.** The other three modules each have one; Negotiation doesn't.
Everything BU-specific here is one of the 8 `NGT` custom attributes.

## Checks

| Check | Result |
|---|---|
| SQL files running against production | 5/5 |
| Row-preservation tests | 4/4 exact |
| Association keys resolving to their parent | 11,842/11,842 |
| NGT custom attributes | 8 configured, 8 in use, no orphans |

## Things we still need to confirm

- 78% of negotiations are unassociated. Expected, or negotiations never linked back
  after the award arrived?
- Two NGT custom attributes have rows but no values.
- Only 3 negotiations link to an Institutional Proposal and 16 to a Subaward — small
  enough to be worth a sanity check.

## Regenerating

```bash
python scripts/build_object_graph.py --module negotiation --source ~/…/kuali-research-bu-master \
    --row-counts <counts.csv> --output modules/negotiation/NEGOTIATION_GRAPH.csv

python scripts/build_frontend_mapping.py --module negotiation --source ~/…/kuali-research-bu-master \
    --dictionary reference/KUALI_FIELD_DICTIONARY.csv --custom-attributes <catalog.csv> \
    --prod-columns <columns.csv> --output modules/negotiation/NEGOTIATION_FRONTEND_DATABASE_MAPPING.csv
```
