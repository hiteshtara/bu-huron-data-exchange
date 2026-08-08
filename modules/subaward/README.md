# Subaward

**Status: COMPLETE**

Root is `org.kuali.kra.subaward.bo.SubAward` → `KCOEUS.SUBAWARD`. Only one class maps to
that table, so unlike Institutional Proposal there was no root-class question to settle.

## What's in here

| File | What it is |
|---|---|
| `SUBAWARD_GRAPH.md` | The graph, and what we found working it out |
| `SUBAWARD_GRAPH.csv` | 32 relationships, machine readable |
| `SUBAWARD_FRONTEND_DATABASE_MAPPING.csv` | 156 UI fields traced to Oracle columns |
| `sql/` | Root plus 11 child collections, read only |
| `sql/json/` | Nested JSON proof of concept for one subaward |

## How we pick the current Subaward

`SUBAWARD` holds 93,061 rows but only 3,466 actual subawards. Every edit creates a new
sequence, so we need a rule for which row represents the subaward today.

The rule is:

```
ACTIVE
  → highest SEQUENCE_NUMBER
    → latest UPDATE_TIMESTAMP
      → highest SUBAWARD_ID
```

That returns exactly 3,466 rows for 3,466 subaward codes. 3,463 come from the ACTIVE
branch and 3 from the fallback.

We tried the obvious thing first and it doesn't work. `MAX(SEQUENCE_NUMBER)` returns
3,534 rows for 3,466 codes, because 62 codes have more than one row sitting at their
highest sequence. In 61 of those 62 the rows are one ACTIVE plus one or more ARCHIVED,
so checking ACTIVE first sorts it out cleanly.

There is a second reason ACTIVE comes before sequence. Five codes have their ACTIVE row
*below* the highest sequence, and in every one of those the higher row is PENDING —
somebody started an amendment and never activated it. If we sorted by sequence first we
would hand Huron those pending rows instead of the real record.

Three codes have no ACTIVE row at all: 1427 is CANCELED, 3699 and 3912 are PENDING. All
three are single-row families, so the fallback branch keeps them without any guesswork.

### Why Subaward 747 needs the timestamp

One subaward, code 747, has two ACTIVE rows. Both sit at sequence 3 and both are
finalized in KEW, so nothing about status or sequence separates them:

| SUBAWARD_ID | Finalized | Amount rows |
|---|---|---|
| 3849 | 12:05:21 | 0 |
| 3850 | 12:06:53 | 1 |

3850 was saved 92 seconds after 3849 and it carries a `SUBAWARD_AMOUNT_INFO` row that
3849 does not have. It is the later and more complete record, so it is the one we want.

We could have broken the tie on `SUBAWARD_ID` and landed on the same row by luck, but
that would have been an arbitrary rule that happened to work. Sorting on
`UPDATE_TIMESTAMP` picks 3850 for an actual reason. We checked whether timestamps ever
tie inside an ACTIVE group anywhere in production and they don't, so this is
deterministic on its own. `SUBAWARD_ID` stays on the end as a backstop but never
actually gets used.

## How Subaward funding connects to Award

This is the join that attaches Subaward to the Award graph, and the important detail is
what KC stores.

`SUBAWARD_FUNDING_SOURCE.AWARD_ID` points at one specific row in `AWARD` — a single
award *version* — not at the award as a whole. KC records the version that existed when
the subaward was funded.

We checked how often that matters. Of the 7,930 funding rows on current subawards,
**5,846 (74%) point at an award version that has since been superseded**. Only 2,084
point at the version that is current today.

### Why we kept the historical AWARD_ID

We left the link exactly as KC recorded it. That version is real history — it says which
award the subaward was funded against at the time — and once you overwrite it with the
current version you cannot get it back. The mapping layer's job is to describe what KC
actually stores.

### How to reach the current Award

The historical link doesn't stop anyone reaching the current award. Every award version
carries the same `AWARD_NUMBER`, and `AWARD_NUMBER` is the stable business key, so:

```sql
huron_subaward_funding_source.funding_award_number = huron_award.award_number
```

We verified every referenced `AWARD_NUMBER` resolves to a selected Award root, so no
subaward is orphaned by that route, and there are no orphan `AWARD_ID` values at all.

The dataset also carries `FUNDING_AWARD_VERSION_IS_CURRENT` (Y/N) and `CURRENT_AWARD_ID`,
so both readings are one column away without anyone having to recompute anything.

3,431 of the 3,466 current subawards have at least one funding source. One has 40.

## SUBAWARD_TYPE_CODE uses the Award lookup

We had this down as unresolved after the Award work, because there is no `SUBAWARD_TYPE`
table in KCOEUS and searching by name finds nothing.

The ORM has the answer: `subAwardType` on `SubAward` points at `AwardType`. Subaward
legitimately reuses the Award type lookup. All 11 codes in production resolve against
`AWARD_TYPE` with nothing unmatched — Cooperative Agreement, Contract, Consortium
Agreement, Grant, Sub-award - Grant, Other Transaction Agreement, Intergovernmental
Personnel Agreement, Sub-award - Contract, Clinical Trial Agreement, CRADA, and
Sub-award - OTA.

This is not a workaround on our side and it is not a data problem. It is how KC is
built.

## Contacts are KIM identities

`SUBAWARD_CONTACT` has no `PERSON_ID` column, which surprises people looking for one.

The ORM offers two identities, `ROLODEX_ID` and `REQUISITIONER_ID`, but production only
uses one. `ROLODEX_ID` is NULL on all 194,207 rows. `REQUISITIONER_ID` is populated on
every single one.

`REQUISITIONER_ID` is a KIM person id. There is no ORM relationship from here to a
person table — KC looks the name up at runtime through its person service — so we expose
the id and do not try to join a name onto it. This is the same situation we found on
Award, where `AWARD_PERSONS.FULL_NAME` turned out to be a denormalized copy rather than
the system of record.

The subaward root separately carries `SITE_INVESTIGATOR`, which *is* a Rolodex id and
does join: 77,130 rows populated, 77,127 matching a `ROLODEX` row.

## Checks

| Check | Result |
|---|---|
| SQL files running against production | 13/13 |
| Row-preservation tests | 8/8 exact |
| Mapped columns verified in production | 103/103 |
| SAWD custom attributes | 15 configured, 15 in use, no orphans |
| Backup tables checked against live code | 15 checked, none live |

## Things we still need to confirm

These are open questions for BU and Huron to work through together, not defects:

- **Historical or current award?** We preserve the award version KC recorded. Whether
  the migration ultimately loads that historical version or associates the subaward with
  the current award is a decision for later — the data supports either.
- **Unused features or data kept elsewhere?** `SUBAWARD_AMT_RELEASED` holds 2 rows in
  the whole table, and `SUBAWARD_CLOSEOUT`, `SUBAWARD_REPORTS` and
  `SUBAWARD_TEMPLATE_ATTACHMENTS` are completely empty. Either BU does not use these
  parts of KC, or the information lives somewhere else.
- **One SAWD custom attribute** has rows but no non-NULL value anywhere.

## Regenerating

```bash
python scripts/build_object_graph.py --module subaward --source ~/…/kuali-research-bu-master \
    --row-counts <counts.csv> --output modules/subaward/SUBAWARD_GRAPH.csv

python scripts/build_frontend_mapping.py --module subaward --source ~/…/kuali-research-bu-master \
    --dictionary reference/KUALI_FIELD_DICTIONARY.csv --custom-attributes <catalog.csv> \
    --prod-columns <columns.csv> --output modules/subaward/SUBAWARD_FRONTEND_DATABASE_MAPPING.csv
```
