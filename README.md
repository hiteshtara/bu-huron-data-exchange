# BU Huron Data Exchange

Repository for Boston University Huron data exchange, migration, validation, reconciliation, and integration work.

## Scope

This repository is for data work only:

- KC / Oracle extracts
- Huron migrations
- source-to-target mappings
- SAP / Huron integration analysis
- transformation rules
- reconciliation
- validation
- migration troubleshooting
- runbooks and reference material

## Structure

Directories are created when work actually starts in them, so the tree reflects real
work rather than a template.

```text
bu-huron-data-exchange/
├── CLAUDE.md
├── README.md
├── scripts/                    # read-only production runner + build scripts
├── reference/
│   ├── award/                  # Award object graph + front-end field mapping
│   ├── kuali/                  # KUALI_FIELD_DICTIONARY.csv (all modules)
│   └── package/                # frozen 359-table discovery package (data gitignored)
├── sql/
│   ├── extraction/             # discovery + custom-data extract queries
│   ├── reconciliation/
│   └── views/                  # SELECT-only logical interface for Huron
│       ├── award/              # root + child collections + json/ proof of concept
│       ├── proposal/           # next
│       ├── subaward/
│       ├── negotiation/
│       └── reference/
├── mappings/                   # source-to-target field mappings
├── issues/
└── runbooks/
```

### Current state

| Module | Graph | Front-end mapping | SQL interface |
|---|---|---|---|
| Award | done | done | done (root + 22 children + JSON PoC) |
| Institutional Proposal | next | next | next |
| Subaward | — | — | — |
| Negotiation | — | — | — |

Per-module work follows one method: root object from the Kuali source → complete
relationship graph → current-version selection rule validated against production →
front-end field-to-database mapping → BU extensions and custom attributes → SQL views
last.

## Naming

Use descriptive filenames.

Good:

```text
irb_active_protocol_population.sql
award_active_version_extract.sql
subaward_source_target_reconciliation.sql
sap_country_code_validation.sql
```

Avoid:

```text
query1.sql
test.sql
final.sql
final2.sql
```

## Suggested Workflow

1. Put raw/source documentation in `reference/`.
2. Put field mappings in `mappings/<module>/`.
3. Put extraction SQL in `sql/extraction/`.
4. Put migration-specific files in `migrations/<module>/`.
5. Put comparison queries in `sql/reconciliation/`.
6. Record defects in `issues/`.
7. Capture repeatable procedures in `runbooks/`.
