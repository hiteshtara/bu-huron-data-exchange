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
| **Selected current record** | The row our module-specific rule chooses as the source representation of the business object. Each module has its own rule, proven from production — see the module's validation query. Not simply "the ACTIVE row" and not `MAX(SEQUENCE_NUMBER)`; both have fallback cases. |
| **ACTIVE** | A KC *sequence-status* value, used by the Award, Institutional Proposal and Subaward selection logic where it applies. It is one input to the rule, not the rule itself. |
| **Finalized** | Workflow/document state in KEW. It describes where a document reached in routing, and is **not** a synonym for ACTIVE or for the selected current record. |
| **Lineage key** | A column carried through every dataset so a child can be tied back to its parent — `AWARD_ID`, `AWARD_NUMBER`, `SEQUENCE_NUMBER` and so on. |
| **Root / child collection** | The root is one row per business record. Child collections are the one-to-many parts (people, amounts, terms) kept in separate queries so they cannot multiply the root. |
| **EAV** | Entity-attribute-value. Instead of a column per field, one table stores a row per field with an attribute id and a generic `VALUE`. KC stores BU's custom fields this way. |
| **Custom attribute** | A field BU configured itself, defined in `CUSTOM_ATTRIBUTE` and stored in a `*_CUSTOM_DATA` table. |
| **BU extension** | A table BU added alongside a stock KC table to hold extra fields — `AWARD_EXTENSION`, `PROPOSAL_EXTENSION`, `SUBAWARD_EXTENSION`. The Java classes live under `edu.bu`. |
| **Polymorphic key** | A column whose meaning depends on another column. `NEGOTIATION.ASSOCIATED_DOCUMENT_ID` is an award number, a subaward code or a proposal number depending on the association type. |
| **Row multiplication** | What happens when one-to-many collections are joined together — an award with 5 people and 12 terms becomes 60 rows. The main thing the dataset design avoids. |

## Awards, families and subawards

These four are easy to confuse, and two of them sound almost identical while meaning
opposite things.

| Term | What it means |
|---|---|
| **Award family** | The root/main Award together with its child/subaccount Award records. Identified structurally by `ROOT_AWARD_NUMBER`. 15,729 of them. |
| **Root / main Award** | The `-00001` award at the top of a family. It is the family's primary award record. |
| **Child Award / subaccount Award** | A non-root `AWARD_NUMBER` inside an Award family. It is another BU Award/account in the same family, with its own account number and money, and it can itself have children. |
| **Subaward** | A **separate KC business object**, modelled under `modules/subaward/`. It represents BU's outgoing subaward relationship — work BU is funding at another institution — and can link back to an Award through `SUBAWARD_FUNDING_SOURCE`. |

**A child Award/subaccount is not a Subaward.** A child Award is an account *inside* BU's
own award structure. A Subaward is a relationship with an *external* organisation. They
are different objects, in different modules, with different keys.

Nothing in the data says every child Award has a Subaward, or that a Subaward corresponds
one-to-one with a child Award. We have not tested for either, so do not assume it.

## Relationship types in the graph CSVs

| Type | Meaning |
|---|---|
| `ONE_TO_ONE` | Exactly one child per parent, or none |
| `MANY_TO_ONE` | Many parents point at one row — usually a lookup |
| `ONE_TO_MANY` | A collection; kept as its own dataset |
| `MANY_TO_ONE_INVERSE` | A child pointing back at its parent. Navigation only, not exposed |
