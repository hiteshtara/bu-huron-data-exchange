# Grants Data Dump for Huron — AI Mapping Head Start

## Problem

Huron (Phil) has offered a no-cost head start on the Grants conversion: BU sends a data
dump of everything it wants to migrate into HRS v12 Grants, and Huron runs its AI mapping
tooling to produce a first-pass source-to-target mapping (the same approach used on IRB).

Phil's constraints, verbatim:

- "BU sends **all the data** you have and would like to migrate."
- "**Fields are more important than all the rows**, but as close to everything as you can
  reasonably obtain."
- "Any **data-file format** is sufficient as long as **column headers are clearly defined**."
- "Data can be in the form of **files or a SQL table** if you prefer."

## Scope of this package

This package is for **Huron field discovery and AI mapping only**. It is **not** a final
migration extract, **not** cleansed to final data-quality standards, and **not** the final
population selection for conversion. The goal (per Phil) is **fields over rows**: complete
column coverage with clear headers plus enough real values to infer meaning. Final population
selection, cleansing, and reconciliation happen later during the migration itself.

Data anomalies found during discovery are **reported, not fixed** (see *Open questions*).

## Source — confirmed against production

| | |
|---|---|
| System | Kuali Coeus (KC) on Oracle |
| Host | `prod.db.kuali.research.bu.edu` (DB `KUALI`) |
| Schema | **KCOEUS — production** |
| Access | READ ONLY, via `scripts/kc_prod_readonly_query.py` (`SET TRANSACTION READ ONLY`; only `SELECT`/`WITH` permitted) |
| Discovery date | 2026-08-07 |
| Application source | BU fork `kuali-research-bu-master` (branch `bu-master`), inspected read-only |

Every table and column name in this package was **confirmed from live production metadata**
(`ALL_TABLES` / `ALL_TAB_COLUMNS` / `ALL_CONSTRAINTS`). Row counts are **actual `COUNT(*)`
values**, not optimiser statistics. Nothing is assumed.

> Earlier drafts of this document described the source as the KCOEUS *staging* schema. The
> package is now built from **production**.

## What discovery found

| Measure | Value |
|---|---|
| Tables in KCOEUS | 901 |
| Tables in Grants scope | **359** |
| Tables excluded | 542 (reason-coded, see `02_excluded_tables.csv`) |
| Columns in scope | **4,074** |
| Columns with a Kuali UI label | 1,983 |
| Oracle column comments in KC | **0** |
| BU custom attributes configured | **107** |

Two findings shape the package:

1. **KC carries no Oracle column comments at all.** The database alone cannot tell Huron what
   a column means. The business meaning lives in the Kuali application's DataDictionary, which
   is why this package ships `KUALI_FIELD_DICTIONARY.csv` (below) rather than a bare schema dump.

2. **BU's custom fields are EAV.** `AWARD_CUSTOM_DATA.VALUE` is not a business field — it is
   generic storage. The logical field is `CUSTOM_ATTRIBUTE_ID` plus its definition in
   `CUSTOM_ATTRIBUTE`. Handing Huron raw EAV rows would ask their AI to infer meaning from an
   integer, so BU resolves that before delivery.

## The field dictionary — the most valuable artifact

`reference/KUALI_FIELD_DICTIONARY.csv` (6,194 rows) chains each field end to end:

```
Oracle table/column -> Java object/property -> Kuali UI label
                    -> lookup/reference object -> BU custom attribute
                    -> mapping priority
```

Built by `scripts/build_kuali_field_dictionary.py` from four sources:

| Source | Provides |
|---|---|
| OJB `repository-*.xml` (573 class-descriptors) | table + column ↔ Java class + property |
| JPA `@Table` / `@Column` annotations (136 entities) | same, for newer entities (Sponsor, Organization, Unit) |
| Kuali DataDictionary Spring beans (850 entries, 4,111 attribute definitions) | **the front-end field label**, description, lookup |
| KCOEUS production | datatypes, lengths, and BU's configured custom attributes |

**A Java property name is never treated as a UI label.** `UI_FIELD_NAME` is populated only
where a DataDictionary label resolves from source; otherwise it is left empty and noted. This
matters — several fields would be mis-mapped from the property name alone:

| Oracle column | Java property | Actual UI label |
|---|---|---|
| `AWARD.AWARD_NUMBER` | `awardNumber` | **Award ID** |
| `AWARD.SPONSOR_CODE` | `sponsorCode` | **Sponsor ID** |
| `AWARD.LEAD_UNIT_NUMBER` | `unitNumber` | **Lead Unit Number** |
| `PROPOSAL.TITLE` | `title` | **Project Title** |
| `SUBAWARD.SUBAWARD_CODE` | `subAwardCode` | **Subaward ID** |

The labels were validated against a live BU Kuali Award screen: **15 of 15 checked fields
matched exactly**, including three BU extension fields (Grant Number, Federal Clinical Trial,
Prime Sponsor Award ID).

### FIELD_ORIGIN

| Value | Rows | Meaning |
|---|---|---|
| `CORE_KUALI` | 4,086 | stock KC field |
| `LOOKUP_REFERENCE` | 1,922 | field on a reference/code table |
| `BU_CUSTOM_ATTRIBUTE` | 149 | BU-configured custom field (107 distinct attributes) |
| `BU_EXTENSION` | 37 | BU extension table column (`*_EXTENSION`) |

### MAPPING_PRIORITY

So Huron's tooling can focus on business meaning instead of treating every technical column
equally:

| Value | Rows | Rule |
|---|---|---|
| `HIGH` | 2,548 | lineage keys, primary keys, BU custom/extension fields, labelled business fields |
| `MEDIUM` | 1,239 | labelled non-business or unlabelled in-scope fields |
| `LOW` | 238 | peripheral, unlabelled |
| `NOT_FOR_HURON` | 2,169 | `OBJ_ID`, `VER_NBR`, `UPDATE_TIMESTAMP`, `UPDATE_USER`, … |

## BU custom fields — resolved before delivery

BU has **107 custom attributes** configured. Module applicability comes from
`CUSTOM_ATTRIBUTE_DOCUMENT.DOCUMENT_TYPE_CODE` — **authoritative configuration** — and is never
inferred from the mere presence of a value:

| Document type | Module | Attributes |
|---|---|---|
| `AWRD` | Award | 46 |
| `INPR` | Institutional Proposal | 45 |
| `SAWD` | Subaward | 15 |
| `NGT` | Negotiation | 8 |
| `PRDV` | Proposal Development | 4 |
| `PROT` | Protocol / IRB (out of Grants scope) | 28 |
| *(none)* | not attached to any document type | 3 |

The package ships **both** representations:

1. **Normalized** (`custom_fields/*_custom_data_normalized.csv`) — one row per
   record + sequence + attribute, with the definition joined on:
   `MODULE, RECORD_NUMBER, RECORD_ID, SEQUENCE_NUMBER, CUSTOM_ATTRIBUTE_ID,
   CUSTOM_ATTRIBUTE_NAME, CUSTOM_ATTRIBUTE_LABEL, GROUP_NAME, DATA_TYPE, CUSTOM_VALUE`.
   Preserves lineage and completeness.

2. **Pivoted / wide** (`custom_fields/*_custom_fields_wide.csv`) — one row per record, one
   **named column per custom field**, so Huron's AI sees `PRIME_SPONSOR_AWARD_ID` rather than
   `CUSTOM_ATTRIBUTE_ID = 1234`. Each pivot ships a `*_columns.csv` header dictionary mapping
   every generated column back to its attribute id, name, label, group, and datatype.

## Deliverable package

```
discovery/
├── 00_PACKAGE_README.txt                       # what this is, source, conventions, contact
├── 01_data_dictionary.csv              # 4,074 in-scope columns + UI label + priority
├── 02_table_manifest.csv               # 359 in-scope tables: domain, extract type, keys, PII
├── 02_excluded_tables.csv              # 542 excluded tables, each with a reason code
├── 02_extract_log.csv                  # per-table extract result and row count
├── award/                              # FULL + SAMPLE data files
├── institutional_proposal/
├── proposal/                           # Proposal Development / budgets / S2S
├── subaward/
├── negotiation/
├── reference/                          # sponsor, organization, unit, lookups (FULL)
├── bu_custom/                          # custom-attribute definitions and EAV tables
└── custom_fields/                      # normalized + pivoted BU custom fields
```

Plus, outside the shipped package:

```
reference/KUALI_FIELD_DICTIONARY.csv         # the full field trace (6,194 rows)
```

### Extract types

| Type | Tables | Rule |
|---|---|---|
| `FULL` | 164 | ≤ 20,000 rows — reference/master/lookup, sent complete so coded values decode |
| `SAMPLE` | 76 | large transactional/history — ~1,000 rows spread across the table |
| `EMPTY` | 119 | zero rows in production — columns documented, no data file |

Samples retain **all columns and all lineage keys** (`award_id`, `award_number`,
`proposal_id`, `proposal_number`, `subaward_id`, `subaward_code`, `negotiation_id`,
`sequence_number`, `document_number`, `sponsor_code`, `unit_number`, `organization_id`).
Only the row count is reduced — never the column set. Sampling uses
`ROW_NUMBER() OVER (ORDER BY ROWID)` with a modulo step so rows are spread across the whole
table rather than taken from the physical head.

### Exclusions

542 tables excluded, every one reason-coded in `02_excluded_tables.csv`:

| Reason | Tables |
|---|---|
| `WORKFLOW_IDENTITY_INFRA` | 261 | KREW/KRIM/KRMS/quartz platform tables |
| `IRB_IACUC_MODULE` | 174 | different Huron module |
| `BU_TEMP_WORKING` | 38 | `BU_TEMP_*` working tables (all empty) |
| `BACKUP_COPY` | 29 | `*_BKUP` / `*_BKP` / `*_BAK` copies |
| `QUESTIONNAIRE_MODULE` | 13 | questionnaire/YNQ subsystem |
| `PMC_MODULE` | 9 | |
| `NOT_GRANTS_SCOPE` | 8 | matched no Grants domain rule |
| `DATED_SNAPSHOT` | 3 | dated snapshots e.g. `AWARD_REPORT_TRACKING_20180517` |
| `TEMP_WORKING` | 3 | |
| `SMOKE_TEST` | 2 | |
| `DELETED_ROWS_COPY` | 1 | `SUBAWARD_AMOUNT_INFO_DELETED` |
| `REPAIR_FIX_TABLE` | 1 | |

Exclusion is deliberately conservative: only unambiguous markers (dated suffix, `_BKUP`,
`BU_TEMP_`, `_DELETED`, `_FIX_`) exclude a table. Legitimate KC objects whose names merely
contain `TEMPLATE` (e.g. `AWARD_TEMPLATE`, `SUBAWARD_TEMPLATE_INFO`) are **kept**.

## Column-header standard (per Phil)

- Native KC column names, unrenamed (`AWARD_NUMBER`, `SPONSOR_CODE`) — the AI maps better when
  it can cross-reference the data dictionary and lookup tables by real column name.
- UTF-8, comma-delimited, `"` quoting, ISO dates (`YYYY-MM-DD HH24:MI:SS`), empty field for NULL, LF line endings.
- Pivoted custom-field files use readable label-derived headers, each defined in its companion
  `*_columns.csv`.

## Data safety

- **CLOB** columns truncated to 1,000 characters; **BLOB** columns replaced by byte length —
  file content is useless to a field mapper.
- **PII redacted**: in person/contact tables, name/email/phone/address columns and any
  SSN/DOB/citizenship/gender/race/salary column are emitted as `REDACTED`. The column remains
  so structure is visible. PII tables are sampled at 100 rows rather than 1,000.
- No credentials, connection strings, tokens, or keys appear anywhere in the package.
- **Data-governance sign-off is still required before anything leaves BU**, and delivery must
  use BU's approved secure channel — not email attachments.

## Validation / reconciliation

```text
Tables in KCOEUS production:      901
Tables in Grants scope:           359
Tables excluded (reason-coded):   542
  359 + 542 = 901                 reconciled

In-scope by extract type:
  FULL                            164
  SAMPLE                           76
  EMPTY (no data file)            119
  164 + 76 + 119 = 359            reconciled

Columns documented:             4,074
Columns with UI label:          1,983
BU custom attributes:             107
Field dictionary rows:          6,194
```

## Open questions for BU

These were found during discovery and are **deliberately not resolved** here:

1. **Proposal Development appears unused.** `EPS_PROPOSAL` holds **1 row** while
   `PROPOSAL` (Institutional Proposal) holds **130,121**. Confirm BU does not use KC Proposal
   Development, so Huron does not size a conversion for it.

2. **Budgets belong to Awards, not proposals.** `BUDGET` holds 80,248 rows and
   `AWARD_BUDGET_EXT` 80,145 — award budgets. But `EPS_PROP_RATES` holds **1,895,754** rows
   despite Proposal Development being empty. Confirm which module owns these rate rows.

3. **Custom attribute 1212 "Contract" is attached to no document type**, yet has values in
   both `AWARD_CUSTOM_DATA` and `PROPOSAL_CUSTOM_DATA`. Two other attributes are likewise
   unattached. Should they be migrated?

4. **Custom attribute 1213 "Billing Agreement"** is attached only to `AWRD` but has values in
   `PROPOSAL_CUSTOM_DATA`. Confirm intended module.

5. **Several custom attributes have value rows where every value is NULL** (flagged in the
   dictionary `NOTES`). Confirm whether those fields are still in use.

6. **`ORGANIZATION` and `UNIT` labels are partly unresolved** — 37/41 and 5/9 columns have DD
   labels; the rest are technical columns. No labels were invented.

7. **Row-sample size and format** still need Phil's confirmation (see
   `discovery/HURON_REPLY_DRAFT.md`): sample size, CSV vs SQL table, and secure channel.

## Result

_Record here once the package is delivered: delivery date, channel, Huron recipient, and the
counts actually sent._
