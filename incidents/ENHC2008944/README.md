# ENHC2008944 — Limited Submission Opportunity in the award reporting views

BU asked for the custom field Limited Submission Opportunity to show up in the two
SAP BW award reporting views. Deployed and validated on **2026-09-11**.

| File | What it is |
|---|---|
| [sql/AWARDS_MAXSEQ.sql](sql/AWARDS_MAXSEQ.sql) | Deployed definition of `SAPBWKCRM.AWARDS_MAXSEQ` |
| [sql/AAI_AAT_MAXSEQ.sql](sql/AAI_AAT_MAXSEQ.sql) | Deployed definition of `SAPBWKCRM.AAI_AAT_MAXSEQ` |
| [sql/grants.sql](sql/grants.sql) | The grants on both views, and how to prove they survived |
| [sql/validation.sql](sql/validation.sql) | The checks we ran, with the answers we got |

Both SQL files are the text we read back out of `DBA_VIEWS` after deploying, not a
copy of what we intended to deploy. If they ever stop matching production, production
is right and these files are stale.

## Where this sits in the chain

```
SOURCE            KCOEUS.AWARD_CUSTOM_DATA, CUSTOM_ATTRIBUTE_ID = 9
TRANSFORMATION    SAPBWKCRM.AWARD_CUSTOM_DATA pivots that row into a column
TARGET            SAPBWKCRM.AWARDS_MAXSEQ (col 113), SAPBWKCRM.AAI_AAT_MAXSEQ (col 38)
VALIDATION        sql/validation.sql
```

Only the last step was new work. `SAPBWKCRM.AWARD_CUSTOM_DATA` already had
`LIMITED_SUBMISSION_OPPORTUNITY` as `CAST(UPPER(...) AS VARCHAR(1))` at position 29,
so we changed nothing there.

## The field

| | |
|---|---|
| Kuali attribute | `Limited_Submission_Opportunity`, `CUSTOM_ATTRIBUTE_ID` 9 |
| Attribute type | Boolean (`DATA_TYPE_CODE` 4) |
| Source | `SAPBWKCRM.AWARD_CUSTOM_DATA.LIMITED_SUBMISSION_OPPORTUNITY`, `VARCHAR2(1)` |
| In both views | `VARCHAR2(1)` |

## Everything comes out null right now, and that is fine

Attribute 9 had **12,902 rows and zero non-null values** in
`KCOEUS.AWARD_CUSTOM_DATA` when we checked on 2026-09-11. The field is configured in
Kuali but nobody has entered a value yet.

So "select 20 non-null values" returns nothing, and that is the expected answer today,
not a failed deploy. Check 5 in [sql/validation.sql](sql/validation.sql) is the one to
run instead — it proves the column resolves and the join reaches
`AWARD_CUSTOM_DATA` without needing any data to exist. When BU starts using the field
the values will appear on their own; neither view needs another change.

The same is true of the proposal side, which has 8,071 rows and no values.

## AWARDS_MAXSEQ

One line. The view already joined the custom data:

```sql
LEFT JOIN SAPBWKCRM.AWARD_CUSTOM_DATA CUSTOM
  ON CUSTOM.AWARD_ID = A.AWARD_ID
```

so all we did was expose `CUSTOM.LIMITED_SUBMISSION_OPPORTUNITY` after
`PREAWARD_DEPT_ADMIN_EMAIL`, making it column 113. No new join, no filter change.

We appended rather than grouping it with the other `CUSTOM.*` fields on purpose. Putting
it next to `GRANT_TERMINATION` where it reads more naturally would have shifted the
ordinal of seven existing columns, including both `PREAWARD_DEPT_ADMIN` fields.

`PREAWARD_DEPT_ADMIN_NAME` and `PREAWARD_DEPT_ADMIN_EMAIL` (columns 111 and 112) and the
`ROW_NUMBER()` subquery over `V_PROPOSAL_PREAWARD_ADMIN` that feeds them are earlier
work and came through untouched. We checked that specifically, because an early draft of
this change had dropped them.

Row count before and after: **43,406**, with 43,300 distinct `AWARD_ID`. The 106 extra
rows are from the PI non-lead-unit join aliased `C` and were already there.

## AAI_AAT_MAXSEQ

Harder, for three reasons.

**It is `UNION`, not `UNION ALL`.** That matters more than it looks. `UNION`
deduplicates, so adding a column can change the row count by splitting rows that used to
be identical. This column cannot do that: it is functionally dependent on `AWARD_ID`,
and both branches already select `AWARD_ID`, so two rows that matched before still
match. Check 7 in [sql/validation.sql](sql/validation.sql) tests it. Leave the `UNION`
alone.

**Branch 1 needed its columns qualified.** The outer select used bare column names.
`AWARD_CUSTOM_DATA` also has an `AWARD_ID`, so as soon as `CUSTOM` came into scope the
unqualified `AWARD_ID` became ambiguous and the view would not compile — ORA-00918. The
deployed version qualifies branch 1 with `R.`.

**Join on `AWARD_ID`, never `AWARD_NUMBER`.** `SAPBWKCRM.AWARD_CUSTOM_DATA` has no
`AWARD_NUMBER` column at all, so joining on it fails outright with ORA-00904. And even
if the column existed it would be the wrong key: an award number covers every version of
the award. There are 249,970 custom-data `AWARD_ID`s spread over 43,483 award numbers,
35,177 of which have more than one, and the worst has 545. That join would have
multiplied rows instead of adding a column.

Both branches join the same way and end with the same column:

| Branch | Join | Last column |
|---|---|---|
| 1 | `CUSTOM.AWARD_ID = R.AWARD_ID` | `CUSTOM.LIMITED_SUBMISSION_OPPORTUNITY` |
| 2 | `CUSTOM.AWARD_ID = P.AWARD_ID` | `CUSTOM.LIMITED_SUBMISSION_OPPORTUNITY` |

Because `AWARD_CUSTOM_DATA` is exactly one row per `AWARD_ID`, both joins are
many-to-one and neither can add a row.

## Comments we lost

The deploy reformatted `AAI_AAT_MAXSEQ` end to end, and twelve inline comments went
with it. The SQL behaves the same, but two pieces of knowledge are no longer written
down in the view:

- Six comments marking `ANTICIPATED_DIRECT_COSTS`, `ANTICIPATED_F_AND_A_COSTS` and
  `TOTAL_ANTICIPATED_COSTS` as retiring in favour of the `AWARDS_MAXSEQ` equivalents,
  citing ENHC0016735.
- Six of mkousheh's notes explaining that the `AWARD_ID` matching was deliberately
  removed from the `TEMP_TAB` joins because of the 5.2 AAI data model change.

The second one is the one worth caring about. It is the reason those joins are on
`AWARD_NUMBER` alone, and without it the next person to read the view may well try to
"fix" them by adding `AWARD_ID` back. Worth restoring as a comment-only change.

`AWARDS_MAXSEQ` was not reformatted and lost nothing.

## What we checked

Full queries and recorded answers are in [sql/validation.sql](sql/validation.sql).

| Check | Result |
|---|---|
| Both views compile | `VALID` |
| Column position and type | 113 and 38, both `VARCHAR2(1)` |
| `AWARDS_MAXSEQ` row count | 43,406 before and after |
| `AWARDS_MAXSEQ` grain | 43,300 distinct `AWARD_ID`, 106 pre-existing extra rows, unchanged |
| Grants | All seven still present |
| Non-null values | None, as expected |
| Downstream objects | Two invalid, cause not provable either way — see below |

`CREATE OR REPLACE VIEW` keeps grants, and we confirmed it rather than assuming it.

Four objects depend on these two views. `AWARD_PROPOSAL_BRIDGE` and
`REPORT_PARENT_AWARDS` are valid. `PROTOCOL_FUNDING_SOURCE` and
`SUBAWARD_FUNDING_SOURCE_MAXSEQ` are currently INVALID.

The catalog evidence strongly suggests they were already part of a pre-existing
invalid-object group from 15 June 2026. Each of them shares a `LAST_DDL_TIME` to the
second with invalid siblings that do not depend on these two views at all:

| `LAST_DDL_TIME` | Object | Depends on the ENHC2008944 views |
|---|---|---|
| 2026-06-15 00:44:00 | `SUBAWARD_COMPOSITE_MAXSEQ` | no |
| 2026-06-15 00:44:00 | `SUBAWARD_FUNDING_SOURCE_MAXSEQ` | yes |
| 2026-06-15 01:02:25 | `PROTOCOL_FUNDING_ENUM` | no |
| 2026-06-15 01:02:25 | `PROTOCOL_FUNDING_SOURCE` | yes |
| 2026-06-15 01:02:26 | `PROTOCOL_COMPOSITE` | no |

We still cannot prove it. Both are HARD dependents of `AWARDS_MAXSEQ`, so the
ENHC2008944 `CREATE OR REPLACE` would have marked them stale as well, and nobody
captured an invalid-object snapshot before the deploy. Oracle does not record when an
object was invalidated, so the two possible causes cannot be separated from the catalog,
and we can neither pin the current invalid state on this ticket nor rule it out.

What we can say is narrower and still useful. Neither view has compile errors in
`DBA_ERRORS`. Neither references `LIMITED_SUBMISSION_OPPORTUNITY`, and neither uses
`SELECT *`, so nothing picked the new column up by accident — the column exists on four
SAPBWKCRM objects and none of them is a dependent. Every upstream object both views
reference is currently VALID, so there is no broken dependency underneath them. And
`AWARD_PROPOSAL_BRIDGE` and `REPORT_PARENT_AWARDS` have the same parent and came through
the same replace valid, which shows dependents of `AWARDS_MAXSEQ` do revalidate normally.

A recompile would settle it in one step. We did not run one, because that is a change to
objects outside this ticket.

## Things we could not check from this repo

`AAI_AAT_MAXSEQ` is granted to `KCRM_SELECT`, `KCRM_UPDATE` and `SAPBWKCRM_READ_ONLY`,
but not to `KCOEUS`. This repo's runner connects as `KCOEUS`, so it gets ORA-01031 on
that view. Two consequences:

- We have no before/after row count for `AAI_AAT_MAXSEQ`. Anyone redeploying it should
  capture the counts in check 3 first and compare them afterwards.
- Checks 3, 4 and 7 need the SAPBWKCRM owner or `SAPBWKCRM_READ_ONLY` to run.

We could still read the definition, because the KCOEUS login can see `DBA_VIEWS`.

## One thing BU may want to look at separately

While confirming that attribute 9 was the right one, we found that
`SAPBWKCRM.AWARD_CUSTOM_DATA` pivots attribute 6 into `TRUMP_EXEC_ORDER_CERT_DET` and
attribute 7 into `TRUMP_EXEC_ORDER_CERT`. In `KCOEUS.CUSTOM_ATTRIBUTE`, 6 is
`Trump_Exec_Order_Cert` and **there is no attribute 7**. So in the award view those two
columns are mislabelled and `TRUMP_EXEC_ORDER_CERT` is permanently null.
`SAPBWKCRM.PROPOSAL_CUSTOM_DATA` maps 5 and 6 correctly.

We left it alone. It is unrelated to this ticket and needs its own change.
