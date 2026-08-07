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

```text
bu-huron-data-exchange/
├── CLAUDE.md
├── README.md
├── mappings/
│   ├── irb/
│   ├── award/
│   ├── proposal/
│   ├── subaward/
│   ├── negotiations/
│   └── common/
├── sql/
│   ├── extraction/
│   ├── validation/
│   ├── reconciliation/
│   ├── troubleshooting/
│   └── fixes/
├── migrations/
│   ├── irb/
│   ├── award/
│   ├── proposal/
│   └── subaward/
├── integrations/
│   ├── sap/
│   ├── huron/
│   └── other/
├── samples/
├── issues/
├── runbooks/
└── reference/
```

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
