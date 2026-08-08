# Where these numbers came from

Every count in this repo is a measurement, not a permanent fact. Production keeps
moving, so this page records when we took the measurements and what we took them
against. `provenance.json` next to it is the machine-readable version.

Regenerate it with `scripts/build_provenance.py` after rebuilding any artifact.

## What we measured against

| | |
|---|---|
| Validated against production | **2026-08-07** |
| Database | KCOEUS on prod.db.kuali.research.bu.edu |
| Repository revision | `b6cf65630ec9` |
| Kuali source branch | `bu-master` |
| Kuali source revision | not available — the source is an extracted zip, not a clone |
| Kuali `pom.xml` version | `2001.0040` |

We could not pin the Kuali source to a commit. The tree came from
`kuali-research-bu-master.zip` rather than a clone, so there is no SHA to read. The
branch name and the `pom.xml` version are what we can actually prove. If this needs
to be exact later, cloning the fork instead of downloading the zip would fix it.

## Population counts, as measured

| Module | Table | Physical rows | Business records |
|---|---|---|---|
| Award | `AWARD` | 282,468 | 43,202 |
| Institutional Proposal | `PROPOSAL` | 130,122 | 36,863 |
| Subaward | `SUBAWARD` | 93,061 | 3,466 |
| Negotiation | `NEGOTIATION` | 11,842 | 11,842 (not versioned) |

These move. Award gained four rows during a single working session while we were
modelling it, which is why the validation queries tolerate small drift rather than
treating it as a defect.

## Generated artifacts

| Artifact | Rows | SHA-256 (first 16) |
|---|---|---|
| `reference/KUALI_FIELD_DICTIONARY.csv` | 6,194 | `0397e8ab96dda71a` |
| `modules/award/AWARD_GRAPH.csv` | 108 | `0423ba2d496ada11` |
| `modules/award/AWARD_FRONTEND_DATABASE_MAPPING.csv` | 238 | `815147db43dac777` |
| `modules/proposal/PROPOSAL_GRAPH.csv` | 64 | `06c3b8e2ee5557ae` |
| `modules/proposal/PROPOSAL_FRONTEND_DATABASE_MAPPING.csv` | 138 | `b5225ee7280ce1bc` |
| `modules/subaward/SUBAWARD_GRAPH.csv` | 32 | `402198e61de5098f` |
| `modules/subaward/SUBAWARD_FRONTEND_DATABASE_MAPPING.csv` | 156 | `7c958d5481419e81` |
| `modules/negotiation/NEGOTIATION_GRAPH.csv` | 15 | `761ac65a95b5cbb8` |
| `modules/negotiation/NEGOTIATION_FRONTEND_DATABASE_MAPPING.csv` | 46 | `f7f91f5cbbc1aeda` |
| `discovery/01_data_dictionary.csv` | 4,074 | `71a97308f1e42cae` |
| `discovery/02_table_manifest.csv` | 359 | `28e768b98803a8cb` |

The hashes are here so you can tell whether a CSV still matches the documentation
that describes it. `scripts/check_docs.py` compares them.
