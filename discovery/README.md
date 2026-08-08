# Discovery

This directory contains the broad KC Grants schema discovery that was used to
determine **what data exists**. It is **not** the final Huron migration interface.

For the Huron interface, see `modules/`.

## What this was

A one-time sweep of all 901 tables in KCOEUS production, classifying every table into
a Grants domain or an exclusion reason, and extracting a sample of each. It answered
"what is in KC?" — the `modules/` work answers "what does Huron need?".

## Contents

| File | What it is |
|---|---|
| `01_data_dictionary.csv` | 4,074 in-scope columns with datatype, UI label, priority |
| `02_table_manifest.csv` | 359 in-scope tables: domain, extract type, keys, PII flag |
| `02_excluded_tables.csv` | 542 excluded tables, each with a reason code |
| `02_extract_log.csv` | Per-table extract result and row count |
| `00_PACKAGE_README.txt` | README that shipped with the package |
| `GRANTS_DATA_DUMP_FOR_HURON.md` | The package plan and findings |
| `HURON_REPLY_DRAFT.md` | Draft reply to Huron (unsent) |
| `sql/` | The extraction queries |
| `output/` | **Gitignored.** Locally generated production row extracts |

## Reconciliation

```text
Tables in KCOEUS production:  901
  in scope:                   359   (FULL 164 / SAMPLE 76 / EMPTY 119)
  excluded:                   542
Columns documented:         4,074
```

## output/ is never committed

`discovery/output/` holds real KCOEUS rows (PII redacted, still institutional data).
It is fully gitignored and reproducible:

```bash
.venv/bin/python scripts/extract_grants_package.py \
    --manifest discovery/02_table_manifest.csv \
    --dictionary discovery/01_data_dictionary.csv \
    --out-root discovery/output --sql-root discovery/sql/package
```
