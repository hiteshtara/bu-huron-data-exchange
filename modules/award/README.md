# Award

Status: **Technical mapping complete · BU validation pending**

The graph, field mapping and SQL are built and verified against production. That is
not the same as the business decisions being settled — see
[the decision register](../../docs/DECISION_REGISTER.md) for what is still open.
Counts measured 2026-08-07 ([provenance](../../docs/PROVENANCE.md)).

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

## Award families: how awards roll up into one funded project

There are three levels in this data, not two, and mixing any of them up is the biggest
risk in the module.

```
GRANT FAMILY (one funded project)
    |
    +-- 123456-00001   root award — the family, and what BU calls the Grant
    |
    +-- 123456-00002   award / account
    +-- 123456-00003   award / account
    +-- 123456-00004   award / account
             |
             +-- 123456-00005   a child can have children of its own
```

**1. The grant family** is the funded project, identified by the root award number.

**2. The award, or account, within it.** `123456-00002` and `-00003` are separate awards
belonging to the same project, each with its own account number and money. These are
*different* records. A child can itself become a parent.

**3. The version of one award.** `123456-00002` sequence 1, 2 and 3 are that one award
edited over time. These are the *same* record.

So the 43,202 award business records — already one row per award, versions collapsed —
roll up into **15,729 grant families**, about 2.7 awards each. If Huron expects one row
per funded project rather than one per account, 15,729 is the number to work from.

BU's original 2012 KCRM-SAP functional specification describes exactly this structure:
the parent award became the SAP Grant, each child became a Sponsored Program, and
grandchildren were explicitly supported. The evidence, and where it disagrees with
today's data, is in [AWARD_GRAPH.md](AWARD_GRAPH.md).

### What we checked in production

| Question | Answer |
|---|---|
| Is the root always the `-00001` award? | Yes. All 15,729 roots end in `-00001`, and every award ending `-00001` is a root |
| Does every award share its root's base number? | Yes, all 43,201 |
| Are the others really separate accounts? | Yes. 27,170 have their own `ACCOUNT_NUMBER` and **none** shares the root's |
| Does nesting exist? | Yes but rarely — 101 awards at level 2, 3 at level 3, in 21 of 15,729 families |
| Family sizes | 199 families hold one award, 14,839 hold 2–5, 612 hold 6–20, 75 hold 21–100, 4 hold over 100. Largest is `207805-00001` with 216 |

Two details worth knowing. Root rows do not have a NULL parent — they carry the sentinel
`000000-00000`. And suffixes go well past `-00003`; we see up to `-00216`.

Although the `-00001` rule holds perfectly today, `huron_award_hierarchy.sql` derives
`IS_ROOT_AWARD` from `AWARD_NUMBER = ROOT_AWARD_NUMBER` rather than from the suffix. That
is what KC actually stores; the numbering is a convention that could drift.

### One row per award number

`AWARD_HIERARCHY` holds 43,241 rows for 43,201 award numbers, so 40 award numbers appear
twice. The interface returns exactly one row each — preferring `ACTIVE = 'Y'`, then the
latest `UPDATE_TIMESTAMP`, then the highest `AWARD_HIERARCHY_ID`, which we confirmed is
deterministic.

That choice is not cosmetic for two of them. `200431-00004` and `201514-00005` each have
an inactive row placing them a level deeper and an active row re-parenting them directly
under the root. We take the active placement, which is why level 2 shows 101 here and
103 in the raw table.

Nothing is hidden. `sql/huron_award_hierarchy_validation.sql` reports every duplicate,
both parent conflicts, and the awards missing from the hierarchy entirely.

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
award, not one of its versions — see the award families section above. It is also not an
OJB collection; KC reaches it through `AwardHierarchyService`, so we added it to the
graph by hand rather than let it be missed.

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
.venv/bin/python scripts/build_object_graph.py --module award --source ~/…/kuali-research-bu-master \
    --row-counts <counts.csv> --output modules/award/AWARD_GRAPH.csv

.venv/bin/python scripts/build_frontend_mapping.py --module award --source ~/…/kuali-research-bu-master \
    --dictionary reference/KUALI_FIELD_DICTIONARY.csv --custom-attributes <catalog.csv> \
    --prod-columns <columns.csv> --output modules/award/AWARD_FRONTEND_DATABASE_MAPPING.csv
```
