# What these datasets guarantee

The SQL documentation explains how the datasets are shaped. This one covers the things
that are easy to assume wrongly — grain, keys, nulls, dates, numbers, and what is and
is not filtered out.

Counts measured 2026-08-07 ([provenance](PROVENANCE.md)).

## Grain

One row per what, for each dataset:

| Dataset kind | One row is | Rows today |
|---|---|---|
| `huron_award` | one Award | 43,202 |
| `huron_proposal` | one Institutional Proposal | 36,863 |
| `huron_subaward` | one Subaward | 3,466 |
| `huron_negotiation` | one Negotiation | 11,842 |
| `huron_<module>_<collection>` | one child record | varies |
| `*_latest_version_validation` | a single summary row of counts | 1 |

The root datasets are already deduplicated to one current record. You do not need to
apply a `MAX(SEQUENCE_NUMBER)` or a status filter on top — doing so would remove real
rows, because for 202 awards and 3 subawards the current record is not the highest
sequence and is not ACTIVE.

## Keys

Every dataset carries its own primary key plus enough lineage to rejoin the graph.

| Module | Root key | Business key | Every child carries |
|---|---|---|---|
| Award | `AWARD_ID` | `AWARD_NUMBER` + `SEQUENCE_NUMBER` | `AWARD_ID`, `AWARD_NUMBER`, `SEQUENCE_NUMBER` |
| Institutional Proposal | `PROPOSAL_ID` | `PROPOSAL_NUMBER` + `SEQUENCE_NUMBER` | `PROPOSAL_ID`, `PROPOSAL_NUMBER`, `SEQUENCE_NUMBER` |
| Subaward | `SUBAWARD_ID` | `SUBAWARD_CODE` + `SEQUENCE_NUMBER` | `SUBAWARD_ID`, `SUBAWARD_CODE`, `SEQUENCE_NUMBER` |
| Negotiation | `NEGOTIATION_ID` | `NEGOTIATION_ID` | `NEGOTIATION_ID` |

Two exceptions, both deliberate. `huron_proposal_log` keys on `PROPOSAL_NUMBER` alone,
because the intake record is not versioned. `huron_negotiation_activity_attachment`
carries `NEGOTIATION_ACTIVITY_ID` as its parent because attachments belong to an
activity, and we join back through the activity to add `NEGOTIATION_ID`.

**Join on the surrogate id for one version, on the business key across modules.**
`AWARD_ID` gets you exactly the version you are holding. `AWARD_NUMBER` gets you the
award regardless of version, which is what you need when a Subaward's funding link points
at an older version than the current one.

### Source keys have to survive the migration

There are three different kinds of identifier in play, and they do not have the same
lifetime:

| Kind | Examples | What happens to it |
|---|---|---|
| **Business / source identifier** | `AWARD_NUMBER`, `PROPOSAL_NUMBER`, `SUBAWARD_CODE`, `NEGOTIATION_ID` | **Must survive.** These are how BU refers to the record, and how a converted record can be tied back to KC |
| **Internal KC relationship / version identifier** | `AWARD_ID`, `PROPOSAL_ID`, `SUBAWARD_ID`, `SEQUENCE_NUMBER` | Needed during staging and reconciliation wherever relationships depend on them. Not necessarily a permanent user-facing field |
| **Huron-native identifier** | assigned at load | Does not exist yet |

The requirement is that the original KC business identifiers are carried into the
converted data, not consumed and discarded during load. Once Huron assigns its own keys,
the KC key is the only thing that ties a converted record back to its source — for
reconciliation, for investigating a discrepancy, and for re-establishing relationships
between objects that were linked in KC.

That last point is worth stating plainly, because it is not obvious until a load has
already happened. Dean put it this way:

> Various objects are linked in the current Kuali (e.g., Proposals to Awards, Subawards to
> Awards). Obviously, these objects link today using the Kuali-based keys. We know when an
> object is converted over to Huron, it will no longer carry the Kuali-native object key.
> It will be assigned a key native to Huron. This is where it will be important to include
> an original source key in any of the converted data.

To be clear about the limit: this does not mean every internal Oracle primary key needs to
become a permanent user-facing field in Huron. It means the business identifiers must
persist, and the internal ones must remain available for as long as the conversion and its
reconciliation need them.

### The source-to-Huron ID crosswalk

Preserving the keys is half of it. The other half is a record-level crosswalk, so that
after load there is a direct answer to "which Huron record is this KC award?" and the
reverse.

Conceptually, one row per converted object:

```
SOURCE_OBJECT_TYPE     AWARD
SOURCE_BUSINESS_KEY    123456-00001
SOURCE_INTERNAL_KEY    <KC AWARD_ID, where a relationship depends on it>
HURON_OBJECT_TYPE      <target type>
HURON_ID               <assigned during load>
```

This is a concept, not something BU has built. Where it lives and who maintains it is
**D-20**, and it needs Huron's input because the Huron-side half of every row is theirs.

Value crosswalks — translating a KC code into an approved Huron value — are a different
thing and are covered in [HURON_USAGE_GUIDE.md](HURON_USAGE_GUIDE.md).

## Current versus historical

The root datasets give you the **current** record. History is not exposed by default.

Each module documents its own rule and each has a validation query that shows the counts
and exceptions. The rules genuinely differ — Award, Proposal and Subaward each needed a
different one, and Negotiation is not versioned at all. `ROOT_SELECTION_RULE` on the
root says which branch of the rule chose that row.

**Three words that are not interchangeable.** They get used loosely in conversation and
mean different things here:

| Term | What it means |
|---|---|
| **Selected current record** | The row our module rule chose as the source representation of the business object. This is what the root datasets contain |
| **ACTIVE** | A KC *sequence-status* value. It is the first test in the Award, Proposal and Subaward rules, but only one input to them |
| **Finalized** | A KEW *workflow/document* state. It says where a document reached in routing. It is not a synonym for ACTIVE, and not a synonym for current |

The distinction matters because the selected current record cannot be defined as "the
ACTIVE row" or as `MAX(SEQUENCE_NUMBER)`. Both have real fallback cases: 202 awards and 80
proposals have no ACTIVE row at all, 10 award numbers have two rows tied at the highest
sequence, and one subaward code has two ACTIVE rows 92 seconds apart. The rule is the
whole chain, not its first step — which is why `ROOT_SELECTION_RULE` records which branch
fired.

Negotiation has none of this. It is not versioned: one row is one negotiation.

If you need history, remove the `huron_<module>_version` join from the query. Everything
else works unchanged.

One relationship deliberately keeps history: `huron_subaward_funding_source` records the
award version KC linked at the time, which for 74% of rows is a superseded version. That
is real data, not a bug. `FUNDING_AWARD_VERSION_IS_CURRENT` and `CURRENT_AWARD_ID` give
you the other reading without losing the original.

## Nulls

A null means one of three things, and the difference matters:

| What you see | What it means |
|---|---|
| A business column is NULL | The field was never filled in |
| A `*_DESCRIPTION` column is NULL beside a populated code | The code did not resolve against its lookup — rare, and the counts are in the module docs |
| A whole block of columns is NULL | The optional relationship does not exist for that row |

The third case is the one to know about. In `huron_proposal`, the six `BU_*` extension
columns are NULL for the 7,762 proposals with no `PROPOSAL_EXTENSION` row. In
`huron_negotiation`, all the `UNASSOCIATED_*` columns are NULL for the 2,593 negotiations
that *are* associated with something. Neither is missing data.

In `huron_award_custom` and its equivalents, a NULL `APPLIES_TO_DOCUMENT_TYPE` means the
attribute has values on this module but is not configured for it. We expose the values
and flag the mismatch rather than dropping the rows.

## Codes and descriptions

Where a code has a lookup, both come through: `STATUS_CODE` next to
`STATUS_DESCRIPTION`, `SUBAWARD_TYPE_CODE` next to `SUBAWARD_TYPE_DESCRIPTION`.

**The code is the stored value and the description is derived.** Map against the code.
Descriptions come from small lookup tables that BU can edit.

Where we could not prove a lookup, there is no description column and we did not invent
one. `SUBAWARD_TYPE_CODE` was in that state until we found in the ORM that Subaward
reuses `AWARD_TYPE`; it now has a description because the relationship is real.

Lookup rows are **not** filtered by any active flag. `SPONSOR` has `ACTV_IND` and we do
not filter on it, because an award legitimately references a sponsor that has since been
made inactive. You get the description that belongs to the stored code.

## Dates

All date columns are Oracle `DATE` or `TIMESTAMP`. **No column in scope carries a time
zone** — there are no `TIMESTAMP WITH TIME ZONE` columns anywhere in KCOEUS.

Business dates carry no meaningful time component: every `AWARD_EFFECTIVE_DATE` in
production is midnight. Audit columns (`UPDATE_TIMESTAMP`, `CREATE_TIMESTAMP`) do carry
a real time.

Times are in whatever zone the database server records, with nothing stored to
disambiguate. For date-only business fields this does not matter. For audit timestamps,
treat them as local server time.

## Numbers

Money is `NUMBER(12,2)` — for example `AWARD_AMOUNT_INFO.ANTICIPATED_TOTAL_AMOUNT` and
`AMOUNT_OBLIGATED_TO_DATE`. Rates and percentages vary by column; the exact precision for
every column is in `discovery/01_data_dictionary.csv`.

We do not round, reformat or convert anything. Values come through as stored.

## Text and large objects

`CLOB` columns are truncated. Comments and descriptions come through as the first 4,000
characters, attachment comments as the first 2,000. The module SQL says which columns
are truncated.

`BLOB` columns are never exposed. Attachment datasets carry metadata — file name, mime
type, type code, `FILE_DATA_ID` — but not file content.

### Attachment identifiers

**`FILE_DATA_ID` is a `VARCHAR2(36)` source identifier and must be preserved as a string.
It must never be converted to `INTEGER`, `BIGINT` or `NUMBER`.** Every populated value in
production is a UUID; a numeric conversion fails on all of them, not on an awkward
minority.

The relationship is:

```
ATTACHMENT_FILE.FILE_DATA_ID  =  FILE_DATA.ID
```

`FILE_DATA` holds only `ID` and `DATA`, so there is no `FILE_DATA.FILE_DATA_ID` to join
to. Institutional Proposal and Subaward attachments carry `FILE_DATA_ID` themselves and
reference `FILE_DATA.ID` directly, without passing through `ATTACHMENT_FILE`.
[DATA_MODEL.md](DATA_MODEL.md) sets out both patterns.

Attachment **metadata** and attachment **binary content** are separate concerns. The
metadata datasets carry the identifiers so the files can be located later; the bytes stay
out of the field-mapping datasets unless binary migration is explicitly in scope, and
adding them would change what those datasets are for.

## What is excluded

Excluded, and why:

- **Technical columns.** `OBJ_ID` is dropped. `VER_NBR` is exposed as `VERSION_NUMBER`
  because it is occasionally useful, and the field dictionary marks these
  `NOT_FOR_HURON`.
- **KEW workflow tables.** Document routing headers are platform plumbing.
- **Backup and snapshot tables.** All reason-coded in
  `discovery/02_excluded_tables.csv`. For Subaward we checked all 15 against live code
  before excluding them.
- **`AWARD_CGB`.** Excluded on evidence: 7 of 14 fields entirely NULL, the other 6 `'N'`
  on all 154,705 rows.

**Not excluded:** cancelled and inactive business records. 194 of the 43,202 Award roots
have `CANCELED` sequence status, and they are in the dataset. We did not filter to a
migration population — deciding which records convert is a later decision, and one that
is much easier to make with everything visible.

## Stability of column names

Output column names are ours, not KC's, and we chose them to be readable — `award_title`
rather than `TITLE`, `bu_grant_number` rather than `GRANT_NUMBER`.

They are stable as far as we are concerned: we will not rename a column without saying
so. If a column name has to change, it will be in the module's git history and worth
raising at the next BU/Huron checkpoint. The underlying `DB_TABLE` and `DB_COLUMN` in the
field dictionary are KC's own names and will not change unless KC changes.

## Reproducibility

Everything here is regenerable. `docs/PROVENANCE.md` records what each artifact was built
from, with a hash per file so you can tell whether a CSV still matches its documentation.
`docs/ONBOARDING.md` covers rebuilding.
