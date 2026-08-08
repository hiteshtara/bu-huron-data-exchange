# docs/

Cross-module documentation that sits above the individual modules. The per-module detail
still lives under `modules/<name>/`; these documents tie it together.

| Document | What it covers |
|---|---|
| [DATA_MODEL.md](DATA_MODEL.md) | How Award, Institutional Proposal, Subaward and Negotiation relate — versioning, the links between them, custom fields, and the shape every module shares. Diagrams included. |
| [HURON_USAGE_GUIDE.md](HURON_USAGE_GUIDE.md) | How Huron can apply the repository to source-to-target mapping, decisions, extraction, transformation, loading and reconciliation. |
| [SQL_INTERFACE.md](SQL_INTERFACE.md) | How each module's `sql/` datasets are organised — root, child collections, custom fields, validation — and the datasets listed module by module. |
| [DECISION_REGISTER.md](DECISION_REGISTER.md) | Cross-module and module-specific questions that require BU/Huron review and an explicit migration decision. |
| [PROVENANCE.md](PROVENANCE.md) | When counts were measured and which source and repository revisions produced the artifacts. |
| [WALKTHROUGH.md](WALKTHROUGH.md) | One real Award end to end — run the root query, pull its people and custom fields, join them back, read `SELECTION_RULE`, check a field against the dictionary. Start here if you want something runnable. |
| [DATA_CONTRACT.md](DATA_CONTRACT.md) | What the datasets guarantee: grain, keys, nulls, dates, numbers, what is excluded, and how stable the column names are. |
| [DECISION_REGISTER.md](DECISION_REGISTER.md) | Every open BU/Huron question in one table, with impact and owner. |
| [PROVENANCE.md](PROVENANCE.md) | When each count was measured and what against, with a hash per artifact. |
| [GLOSSARY.md](GLOSSARY.md) | KC, HRS, OJB, JPA, EAV, lineage key, business record, current version. |
| [ONBOARDING.md](ONBOARDING.md) | Internal setup: the Python environment, database credentials in the Keychain, the read-only runner, and regenerating the generated artifacts. |

For field-level mapping, `reference/KUALI_FIELD_DICTIONARY.csv` and
[HURON_MAPPING_GUIDE.md](../HURON_MAPPING_GUIDE.md) remain the starting point.
