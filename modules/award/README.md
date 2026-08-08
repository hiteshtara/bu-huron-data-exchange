# Award

**Status: COMPLETE**

Root object `org.kuali.kra.award.home.Award` → `KCOEUS.AWARD`.

## Contents

| File | What it is |
|---|---|
| `AWARD_GRAPH.md` | The object graph explained, with the findings that shaped it |
| `AWARD_GRAPH.csv` | 66 relationships, machine readable |
| `AWARD_FRONTEND_DATABASE_MAPPING.csv` | 238 UI fields traced to Oracle columns |
| `sql/` | Read-only Huron interface: root + 21 child collections |
| `sql/json/` | Nested JSON proof of concept (one award) |

## Key decisions

**Population.** One row per `AWARD_NUMBER`: the version KC marks `ACTIVE`, falling back
to the highest sequence where no ACTIVE row exists (202 awards). 43,202 selected rows
for 43,202 award numbers. See `sql/huron_award_latest_version_validation.sql`.

**No flat joins.** Many-to-one lookups are folded into the root as code + description.
One-to-many collections are separate datasets — flattening them would multiply the root.

**Children follow the selected root's `AWARD_ID`.** `MAX(SEQUENCE_NUMBER)` is never
recomputed on a child table.

## Traps found

- `AWARD_HIERARCHY` keys on `AWARD_NUMBER`, not `AWARD_ID`, and is not an OJB collection.
- `EPS_PROP_PERSON_ROLE` holds two rows per role code; unfiltered it doubles personnel
  from 345,600 to 691,200 rows.
- `AWARD_PERSONS.FULL_NAME` is a denormalized copy — `KcPerson` resolves from KIM at
  runtime with no ORM relationship to a person table.
- `AWARD_CGB` was excluded on evidence, not name: 7 of 14 fields are entirely NULL and
  the other 6 are `'N'` on all 154,705 rows.

## Regenerate

```bash
python scripts/build_object_graph.py --module award --source ~/…/kuali-research-bu-master \
    --row-counts <counts.csv> --output modules/award/AWARD_GRAPH.csv
python scripts/build_award_frontend_mapping.py --source … --output modules/award/AWARD_FRONTEND_DATABASE_MAPPING.csv
```
