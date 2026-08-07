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
population selection for conversion. The goal (per Phil) is **fields over rows**: complete column
coverage with clear headers plus enough real values to infer meaning. Final population selection,
cleansing, and reconciliation happen later during the migration itself.

## Source

Kuali Coeus (KC) on Oracle — **KCOEUS staging schema**. Source table and column names in this
package are **confirmed** from the KCOEUS staging schema via schema discovery (2026-08-07); the
generated data dictionary (`01_data_dictionary.csv`) is the authority for every header. In KC,
"Grants" spans these domains:

| Domain | KC module | What it is |
|---|---|---|
| Proposal Development | Pre-award | In-progress / submitted proposals, budgets, narratives |
| Institutional Proposal | Pre-award | Proposals of record (submitted) |
| Award | Post-award | Awards, increments/amounts, terms, hierarchy |
| Subaward | Post-award | Outgoing subawards and their funding sources |
| Negotiation | Pre/Post-award | Negotiation records and activities |
| Common / Reference | Cross-cutting | Sponsors, units, persons, rolodex, rates, lookups, **custom attributes** |

## Business rule — what "everything" should mean here

Because Phil wants **fields over rows**, the goal is *coverage*, not volume. Two extract types,
recorded per table in `02_table_manifest.csv` (`EXTRACT_TYPE`):

1. **Every column** of every in-scope KC Grants table, with a **clear header and datatype**
   (this is the data dictionary — it is the single most valuable artifact for AI mapping).
2. **FULL** — small **reference / master / lookup** tables are exported as the **complete
   population** (sponsors, units, statuses, types, rate types, custom-attribute definitions), so
   coded values (status codes, type codes, sponsor codes, unit numbers) are decodable.
3. **SAMPLE** — large **transactional / history / custom-data** tables are exported as a
   **representative sample** of rows. Samples **retain ALL columns and ALL lineage keys** — only
   the row count is reduced, never the column set. (Final population selection is out of scope
   for this discovery package.)
4. **BU custom attributes** (KC lets institutions add custom fields). These are the fields most
   likely to be missed and most likely to need explicit mapping decisions — include the
   definitions (FULL) and a sample of the `*_custom_data` values (SAMPLE, all columns retained).
5. **Preserve lineage identifiers** on every extract so records can be traced end-to-end:
   `proposal_number`, `proposal_id`, `award_id`, `award_number`, `sequence_number`,
   `document_number`, `subaward_id`, `sponsor_code`, `person_id` / `rolodex_id`, `unit_number`.

## Approach — discovery confirmed, then extract

Schema discovery has been run against the **KCOEUS staging schema**; source object names are
**confirmed** and the module extract scripts are aligned to them. The sequence:

1. **Schema discovery** (`sql/extraction/grants_schema_discovery.sql`) — reads `ALL_TAB_COLUMNS`
   / `ALL_TAB_COMMENTS` and produces the **data dictionary** (`01_data_dictionary.csv`): every
   table, column, datatype, nullability, and comment. This output is itself a deliverable to
   Huron and directly satisfies "column headers clearly defined." *(Done — names confirmed.)*
2. **Run the extracts** — reference/master tables **FULL**
   (`grants_common_reference_extract.sql`), transactional/history/custom-data tables **SAMPLE**
   with all columns + lineage keys retained (`grants_proposal_extract.sql`,
   `grants_award_extract.sql`, `grants_subaward_negotiation_extract.sql`).
3. **Generate the manifest** (`sql/extraction/grants_manifest_generator.sql`) →
   `02_table_manifest.csv`: one classified row per table (domain, extract type, row count, keys).
4. **Assemble the package** (with `00_README.txt`) per the layout below and hand off.

## Deliverable package (what BU sends Huron)

```
bu_grants_dump_for_huron/
├── 00_README.txt                      # what this is, KC version, extract date, contact
├── 01_data_dictionary.csv             # from grants_schema_discovery.sql (all columns)
├── 02_table_manifest.csv              # one row per file: table, grain, row count, PK
├── reference/                         # lookup tables — FULL rows
│   ├── sponsor.csv, unit.csv, rolodex.csv, rate_type.csv, *_status.csv, *_type.csv ...
│   └── custom_attribute.csv           # definitions of BU custom fields
├── proposal/                          # sample rows
├── award/                             # sample rows
├── subaward/                          # sample rows
└── negotiation/                       # sample rows
```

### Column-header standard (per Phil)

Every file's first row = column headers using the **actual KC column names**, plus these
conventions so headers are self-describing:

- Keep native KC column names (e.g. `AWARD_NUMBER`, `SPONSOR_CODE`) — do not rename. The AI
  tool maps better when it can cross-reference the data dictionary and lookup tables by real
  column name.
- UTF-8, comma-delimited, `"` quoting, ISO dates (`YYYY-MM-DD`) for DATE columns, and a
  literal empty field for NULL (document this in `00_README.txt`).
- Include the `*_id` / `*_number` / `sequence_number` lineage keys on every extract even when
  they seem redundant — they are how mappings get validated later.

## Format decision — files vs. SQL table

| Option | When to choose | Notes |
|---|---|---|
| **CSV files** (recommended) | Fastest to produce and review; no schema handoff | Use the manifest so Huron knows the grain of each file |
| **SQL table / schema dump** | If BU prefers to ship a read-only schema | Include DDL + data; still send `01_data_dictionary.csv` |

Recommendation: **CSV + data dictionary**. It is the lowest-friction way to satisfy
"fields over rows, clear headers" and is trivial for Huron's tooling to ingest.

## Data safety — before anything leaves BU

Treat this as institutional data leaving BU's boundary. Before delivery:

- **Redact / exclude secrets**: no credentials, connection strings, API tokens, keys.
- **PII minimization**: person data (rolodex, KIM entity tables) contains names, emails,
  possibly SSNs/DOB in some KC installs. For AI mapping, Huron needs the **shape** of person
  data, not the population — send the person/rolodex **columns** with a small sample, and mask
  free-text/PII values (e.g. hash or tokenize SSN, DOB, home address) unless BU governance has
  cleared full values. Field *names* and *datatypes* are what the mapper needs.
- **Confirm data-governance sign-off** for external transfer, even at no cost, and use BU's
  approved secure transfer channel (not email attachments for anything with PII).

## Validation / reconciliation

Produce a manifest so the handoff is provable and Huron's mapping can be reconciled later:

```text
Domains in scope:            6
Tables discovered:           <n>   (data dictionary)
Tables extracted:            <n>   (manifest)
Reference tables (full):     <n>
Sample-row tables:           <n>
Custom-attribute fields:     <n>
Columns documented:          <n>   (== data dictionary row count)
```

If tables discovered ≠ tables extracted, note the reason (out of scope, empty, restricted).

## Result

_Record here once the package is produced and delivered: date, KC version, row/column counts,
delivery channel, Huron recipient._
