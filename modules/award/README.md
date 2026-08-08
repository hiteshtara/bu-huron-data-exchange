# Award

**Status: COMPLETE**

Root is `org.kuali.kra.award.home.Award` → `KCOEUS.AWARD`.

## What's in here

| File | What it is |
|---|---|
| `AWARD_GRAPH.md` | The graph, and what we found working it out |
| `AWARD_GRAPH.csv` | 108 relationships, machine readable |
| `AWARD_FRONTEND_DATABASE_MAPPING.csv` | 238 UI fields traced to Oracle columns |
| `sql/` | Root plus 21 child collections, read only |
| `sql/json/` | Nested JSON proof of concept for one award |

## How we pick the current Award

`AWARD` holds 282,468 rows but only 43,202 awards. Every edit writes a new sequence, so
we need a rule for which row is the award today.

We use the version KC marks `ACTIVE`, and fall back to the highest sequence for the 202
award numbers that have no ACTIVE row at all. That gives exactly 43,202 rows for 43,202
award numbers. `sql/huron_award_latest_version_validation.sql` shows the counts.

`MAX(SEQUENCE_NUMBER)` on its own does not work here: 10 award numbers have two rows at
the same highest sequence, one ACTIVE and one ARCHIVED. Checking ACTIVE first sorts
those out.

## Why the queries are separate

We keep people, amounts, terms, special reviews and custom fields in their own queries
rather than joining them onto the award. One award with 5 people, 12 terms and 40 custom
fields would otherwise come back as 2,400 duplicate award rows.

Many-to-one lookups are different — a status or a sponsor cannot multiply anything — so
those are folded into the root as code plus description.

Children are always fetched through the selected root's `AWARD_ID`. We never recompute
`MAX(SEQUENCE_NUMBER)` on a child table, because that would mix rows from different
award versions.

## Things that would be easy to get wrong

**`AWARD_HIERARCHY` keys on `AWARD_NUMBER`, not `AWARD_ID`.** The hierarchy describes the
award, not one of its versions. It is also not an OJB collection — KC reaches it through
`AwardHierarchyService` — so we added it to the graph by hand rather than let it be
missed.

**The person role lookup doubles the dataset.** `EPS_PROP_PERSON_ROLE` holds two rows for
every role code, one per sponsor hierarchy. Joined unfiltered it takes personnel from
345,600 rows to 691,200. We pin it to the `DEFAULT` hierarchy, which resolves all
345,600 with nothing unmatched.

**`AWARD_PERSONS.FULL_NAME` is a copy, not the source.** KC refreshes it from the person
record on read. The real person is a KIM identity resolved at runtime, and there is no
ORM relationship from `AWARD_PERSONS` to any person table, so we expose `PERSON_SOURCE`
to make that explicit.

**We excluded `AWARD_CGB` on evidence, not on its name.** Structurally it qualifies —
stock Kuali class, real UI panel, full DataDictionary. But 7 of its 14 business fields
are entirely NULL and the other 6 are `'N'` on all 154,705 rows. The table carries no
information, so migrating it would hand Huron 14 fields with nothing to infer meaning
from.

## Checks

| Check | Result |
|---|---|
| SQL files running against production | 24/24 |
| Row-preservation tests | no dataset multiplies |
| Mapped columns verified in production | 147/147 |
| UI labels validated against a live Award screen | 15/15 matched |

## Regenerating

```bash
python scripts/build_object_graph.py --module award --source ~/…/kuali-research-bu-master \
    --row-counts <counts.csv> --output modules/award/AWARD_GRAPH.csv

python scripts/build_frontend_mapping.py --module award --source ~/…/kuali-research-bu-master \
    --dictionary reference/KUALI_FIELD_DICTIONARY.csv --custom-attributes <catalog.csv> \
    --prod-columns <columns.csv> --output modules/award/AWARD_FRONTEND_DATABASE_MAPPING.csv
```
