# docs/

Cross-module documentation that sits above the individual modules. The per-module detail
still lives under `modules/<name>/`; these three tie it together.

| Document | What it covers |
|---|---|
| [DATA_MODEL.md](DATA_MODEL.md) | How Award, Institutional Proposal, Subaward and Negotiation relate — versioning, the links between them, custom fields, and the shape every module shares. Diagrams included. |
| [SQL_INTERFACE.md](SQL_INTERFACE.md) | How each module's `sql/` datasets are organised — root, child collections, custom fields, validation — and the datasets listed module by module. |
| [ONBOARDING.md](ONBOARDING.md) | Internal setup: the Python environment, database credentials in the Keychain, the read-only runner, and regenerating the generated artifacts. |

For field-level mapping, `reference/KUALI_FIELD_DICTIONARY.csv` and
[HURON_MAPPING_GUIDE.md](../HURON_MAPPING_GUIDE.md) remain the starting point.
