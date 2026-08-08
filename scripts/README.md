# Scripts

All analysis is reproducible from these. Production access is **read only** and goes
through `kc_prod_readonly_query.py` only — no script opens its own connection.

## Database access

| Script | Purpose |
|---|---|
| `kc_prod_readonly_query.py` | Safe READ-ONLY Oracle query runner. Sets `SET TRANSACTION READ ONLY`, accepts only `SELECT`/`WITH`, blocks DML/DDL keywords. Password from macOS Keychain. |
| `kc_staging_query.py` | Same for the KC staging instance. |
| `setup_kc_staging_keychain.sh` | One-time Keychain setup for staging credentials. |

## Metadata and graph builders

| Script | Purpose |
|---|---|
| `build_kuali_field_dictionary.py` | Builds the Oracle → Java → Kuali UI field dictionary from OJB, JPA and DataDictionary metadata, cross-checked against production. Output: `reference/KUALI_FIELD_DICTIONARY.csv`. |
| `build_object_graph.py` | **Generic KC business-object graph builder.** Walks the OJB/JPA relationship model from a configured root and resolves every edge to real tables and production row counts. |
| `build_frontend_mapping.py` | **Generic UI → database mapping builder.** Traces JSP/tag UI fields to Java properties and Oracle columns, resolving labels from the DataDictionary. |

### Retired single-module builders

`build_award_graph.py` and `build_award_frontend_mapping.py` have been **retired** — it was a single-module implementation of
what `build_object_graph.py` and `build_frontend_mapping.py` now do generically, and
both were verified to reproduce their outputs identically before removal. Their history
remains in Git. Award generation is now:

```bash
.venv/bin/python scripts/build_object_graph.py --module award \
    --source ~/Downloads/kuali-research-bu-master \
    --row-counts <row-counts.csv> \
    --output modules/award/AWARD_GRAPH.csv

.venv/bin/python scripts/build_frontend_mapping.py --module award \
    --source ~/Downloads/kuali-research-bu-master \
    --dictionary reference/KUALI_FIELD_DICTIONARY.csv \
    --custom-attributes <catalog.csv> --prod-columns <columns.csv> \
    --output modules/award/AWARD_FRONTEND_DATABASE_MAPPING.csv
```

Add a new module by adding an entry to `MODULES` in each builder.

## Broad discovery tooling

Used for the one-time `discovery/` sweep, not for the Huron interface.

| Script | Purpose |
|---|---|
| `classify_grants_tables.py` | Broad Grants schema discovery/classification — sorts all 901 KCOEUS tables into domains or reason-coded exclusions. |
| `extract_grants_package.py` | Generates the frozen broad discovery package (per-table FULL/SAMPLE extracts with PII redaction). |
| `pivot_custom_data.py` | Converts KC EAV custom data to named/pivoted fields so a custom attribute reads as a field, not as `CUSTOM_ATTRIBUTE_ID`. |
| `validate_grants_package.py` | Validates the generated discovery package — structure, counts, PII redaction, lineage keys. |
