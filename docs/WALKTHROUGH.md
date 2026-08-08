# Five minutes with one Award

The other documents explain how the datasets are shaped. This one walks through a single
real award end to end, so the shape is something you can run rather than read about.

Every query and every value below came from production on 2026-08-07. Award 100473-00001
is a real NSF award and nothing in it is sensitive.

## Before you start

Queries run through the read-only runner:

```bash
.venv/bin/python scripts/kc_prod_readonly_query.py --file <query.sql> --limit 20
```

It only accepts `SELECT` and `WITH`, and it sets the session read-only, so there is no
way to modify anything through it. Add `--output results.csv` to write to a file instead
of the terminal.

## 1. Run the Award root

```bash
.venv/bin/python scripts/kc_prod_readonly_query.py \
    --file modules/award/sql/huron_award.sql --limit 20
```

That returns one row per award — 43,202 rows, not the 282,468 physical rows in `AWARD`.

To follow along with the same award, wrap the query and filter. The queries have their
own `WITH` clause, so wrapping is the simplest way to add a condition:

```sql
SELECT award_id, award_number, sequence_number, root_selection_rule,
       award_title, status_description, sponsor_name, bu_grant_number
FROM (
    -- paste modules/award/sql/huron_award.sql here
)
WHERE award_number = '100473-00001'
```

```text
AWARD_ID   AWARD_NUMBER   SEQUENCE_NUMBER  ROOT_SELECTION_RULE
3038005    100473-00001   35               ACTIVE_STATUS

AWARD_TITLE        IGERT: INTEGRATING COMPUTATIONAL SCIENCE INTO RESEARCH IN BIOLOGICAL NETWORKS
STATUS_DESCRIPTION Closed
SPONSOR_NAME       National Science Foundation
BU_GRANT_NUMBER    50100473
```

## 2. Read what the root row is telling you

Three things in that row are worth pausing on.

**`SEQUENCE_NUMBER` is 35.** This award has 35 versions in `AWARD`. You got one of them.

**`ROOT_SELECTION_RULE` is `ACTIVE_STATUS`.** That says *why* this row was chosen: KC
marks it as the ACTIVE version. The other possible value is `MAX_SEQUENCE_FALLBACK`,
which appears on the 202 awards that have no ACTIVE row at all — for those we fell back to
the highest sequence. If you ever wonder whether a particular award was picked by the
normal rule or by the fallback, this column answers it without re-deriving anything.

**`STATUS_DESCRIPTION` sits beside `STATUS_CODE`.** The root folds descriptive lookups in
so you get both the stored code and its meaning. Lookups cannot multiply rows, so it is
safe to include them.

`BU_GRANT_NUMBER` is a BU extension field, from `AWARD_EXTENSION` rather than `AWARD`.

## 3. Pull the people

```sql
SELECT award_person_id, award_number, sequence_number,
       person_source, full_name, contact_role_description
FROM (
    -- paste modules/award/sql/huron_award_person.sql here
)
WHERE award_number = '100473-00001'
```

```text
AWARD_PERSON_ID  AWARD_NUMBER   SEQ  PERSON_SOURCE  FULL_NAME             ROLE
3038006          100473-00001   35   KIM_PERSON     GARY BENSON           Principal Investigator
3038010          100473-00001   35   KIM_PERSON     JAMES J COLLINS       Co-Investigator
3038012          100473-00001   35   KIM_PERSON     GEOFFREY M COOPER     Co-Investigator
3038014          100473-00001   35   KIM_PERSON     DAVID J WAXMAN        Co-Investigator
```

`PERSON_SOURCE` says where the identity comes from. `KIM_PERSON` means the person is a
KIM identity that KC resolves at runtime, so `FULL_NAME` here is a stored copy rather
than the system of record. `ROLODEX` would mean an external contact that does join to
`ROLODEX`.

## 4. Pull the custom fields

```sql
SELECT custom_attribute_label, custom_value
FROM (
    -- paste modules/award/sql/huron_award_custom.sql here
)
WHERE award_number = '100473-00001' AND custom_value IS NOT NULL
```

```text
CUSTOM_ATTRIBUTE_LABEL                                            CUSTOM_VALUE
International activity? (excluding travel to conferences) (Y/N)   No
Predoctoral Fellowship? (Y/N)                                     No
Postdoctoral Fellowship? (Y/N)                                    No
```

The underlying table stores these as `CUSTOM_ATTRIBUTE_ID` and a generic `VALUE`. The
query joins the definition so each row arrives as a named field. Mapping against
`CUSTOM_ATTRIBUTE_LABEL` is what you want; `VALUE` on its own carries no meaning.

## 5. Reassemble the graph

All three results carry `AWARD_ID`, `AWARD_NUMBER` and `SEQUENCE_NUMBER`, so they join
back together on the keys they already share:

```text
huron_award                    award_id 3038005  ← one row
  huron_award_person           award_id 3038005  ← four rows
  huron_award_custom           award_id 3038005  ← thirty-seven rows
```

Join on `AWARD_ID` when you want one specific version, which is what the datasets give
you by default. Join on `AWARD_NUMBER` when you want the award regardless of version —
that is the key to use when connecting to other modules, because a Subaward's funding
link records a *different* award version than the current one.

This is also why the collections are separate queries. Joining people and custom fields
onto the root at once would turn this one award into 4 × 37 = 148 rows, each repeating
the same award. Multiply that across 43,202 awards and the result stops being usable.

## 6. Check a field against the dictionary

Say you are mapping `AWARD_TITLE` and want to know what BU users call it.
`reference/KUALI_FIELD_DICTIONARY.csv`, filtered to `DB_TABLE = AWARD` and
`DB_COLUMN = TITLE`:

```text
UI_FIELD_NAME     Award Title
JAVA_PROPERTY     title
MAPPING_PRIORITY  HIGH
CONFIDENCE        HIGH
```

`CONFIDENCE = HIGH` means we verified the column exists in production **and** resolved a
label from the Kuali application. Where `UI_FIELD_NAME` is blank we could not find
enough evidence to assert one, so we left it empty rather than guessing.

This is the step that catches the mismatches. `AWARD.AWARD_NUMBER` is "Award ID" on the
screen, not "Award Number". `PROPOSAL.TITLE` is "Project Title". Neither is guessable
from the column name.

## Where to go next

| If you want | Go to |
|---|---|
| The whole field list | [HURON_MAPPING_GUIDE.md](../HURON_MAPPING_GUIDE.md) |
| How the four objects relate | [DATA_MODEL.md](DATA_MODEL.md) |
| What every column means operationally | [DATA_CONTRACT.md](DATA_CONTRACT.md) |
| Why Award has 108 relationships | [AWARD_GRAPH.md](../modules/award/AWARD_GRAPH.md) |
| Open questions | [DECISION_REGISTER.md](DECISION_REGISTER.md) |
