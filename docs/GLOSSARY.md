# Terms used in this repo

Short definitions for the acronyms and the few terms we use in a specific way.

## Systems

| Term | What it means |
|---|---|
| **KC** | Kuali Coeus, BU's current research administration system. Sometimes "Kuali Research". |
| **KCOEUS** | The Oracle schema KC stores its data in. All queries here run against it read-only. |
| **HRS** | Huron Research Suite, the system BU is migrating to. |
| **KEW** | Kuali Enterprise Workflow, the routing engine behind KC documents. Its tables (`KREW_*`) are platform plumbing and we exclude them. |
| **KIM** | Kuali Identity Management, where KC keeps people. Person names are resolved from KIM at runtime rather than joined from a table. |
| **COEUS** | The system BU used before KC. Turns up as legacy identifiers that no longer resolve. |

## How KC is built

| Term | What it means |
|---|---|
| **ORM** | Object-relational mapping — how the application maps Java objects to database tables. We read KC's ORM to work out the graph instead of guessing from table names. |
| **OJB** | Apache ObjectRelationalBridge, the older ORM KC uses. Its `repository-*.xml` files declare which class maps to which table, and the relationships between them. |
| **JPA** | The newer Java persistence standard. Some KC classes use JPA annotations (`@Table`, `@Column`) instead of OJB. We read both. |
| **DataDictionary** | KC's own metadata describing each field, including the label users see on screen. This is where `UI_FIELD_NAME` comes from. |
| **BO** | Business object — a Java class representing something like an Award. |

## How the data is shaped

| Term | What it means |
|---|---|
| **Physical row** | One row in an Oracle table. `AWARD` has 282,468. |
| **Business record** | One actual thing. There are 43,202 awards, each stored as many physical rows. |
| **Version / sequence** | KC keeps every edit as a new row with an incremented `SEQUENCE_NUMBER`, rather than updating in place. |
| **Current version** | The row representing the record today. Each module has its own rule for finding it, proven from production — see the module's validation query. |
| **Lineage key** | A column carried through every dataset so a child can be tied back to its parent — `AWARD_ID`, `AWARD_NUMBER`, `SEQUENCE_NUMBER` and so on. |
| **Root / child collection** | The root is one row per business record. Child collections are the one-to-many parts (people, amounts, terms) kept in separate queries so they cannot multiply the root. |
| **EAV** | Entity-attribute-value. Instead of a column per field, one table stores a row per field with an attribute id and a generic `VALUE`. KC stores BU's custom fields this way. |
| **Custom attribute** | A field BU configured itself, defined in `CUSTOM_ATTRIBUTE` and stored in a `*_CUSTOM_DATA` table. |
| **BU extension** | A table BU added alongside a stock KC table to hold extra fields — `AWARD_EXTENSION`, `PROPOSAL_EXTENSION`, `SUBAWARD_EXTENSION`. The Java classes live under `edu.bu`. |
| **Polymorphic key** | A column whose meaning depends on another column. `NEGOTIATION.ASSOCIATED_DOCUMENT_ID` is an award number, a subaward code or a proposal number depending on the association type. |
| **Row multiplication** | What happens when one-to-many collections are joined together — an award with 5 people and 12 terms becomes 60 rows. The main thing the dataset design avoids. |

## Relationship types in the graph CSVs

| Type | Meaning |
|---|---|
| `ONE_TO_ONE` | Exactly one child per parent, or none |
| `MANY_TO_ONE` | Many parents point at one row — usually a lookup |
| `ONE_TO_MANY` | A collection; kept as its own dataset |
| `MANY_TO_ONE_INVERSE` | A child pointing back at its parent. Navigation only, not exposed |
