# KC Award Business-Object Graph

## Problem

Huron consumes a business object as a **complete graph**, not a single table. To expose
BU's Awards as a SQL interface we first need the real Award object graph — every
relationship that constitutes an Award in Kuali Coeus — established from the KC model
rather than guessed from table names.

## Source of the graph

The graph was derived from **both**:

1. **`~/Downloads/kuali-research-bu-master`** (BU's fork, branch `bu-master`, read-only) —
   the OJB class descriptor for `org.kuali.kra.award.home.Award` in
   `coeus-impl/src/main/resources/org/kuali/kra/award/repository-award.xml`.
   - `<reference-descriptor>` → `MANY_TO_ONE` (or `ONE_TO_ONE`)
   - `<collection-descriptor>` → `ONE_TO_MANY`
2. **KCOEUS production** — every child class resolved to a real table, annotated with its
   actual `COUNT(*)`, so the graph reflects what BU holds, not what KC supports.

Built by `scripts/build_award_graph.py`. Machine-readable form: `AWARD_GRAPH.csv`.

**66 relationships** discovered: 24 `MANY_TO_ONE`, 37 `ONE_TO_MANY`, 1 `ONE_TO_ONE`,
4 `MANY_TO_ONE_INVERSE`. 54 proposed for exposure, 12 excluded.

## Root object

| | |
|---|---|
| Java class | `org.kuali.kra.award.home.Award` |
| Root table | `KCOEUS.AWARD` (57 columns, 282,468 rows) |
| Primary key | `AWARD_ID` |
| Business key | `AWARD_NUMBER` + `SEQUENCE_NUMBER` |

**Award is versioned.** One `AWARD_NUMBER` has many `SEQUENCE_NUMBER`s, each its own
`AWARD_ID` row. 282,468 rows do **not** mean 282,468 awards. Nothing here filters to the
latest sequence — population selection is a later migration decision.

Every child collection keys on `AWARD_ID`, so children belong to a **specific award
version**, not to the award as a whole. The exceptions are called out below.

## Graph shape

```
AWARD (root, AWARD_ID)
│
├── ONE_TO_ONE
│   └── extension ................ AWARD_EXTENSION (BU) ............ 1:1 on AWARD_ID
│
├── MANY_TO_ONE (folded into the root SELECT as code + description)
│   ├── sponsor / primeSponsor ... SPONSOR
│   ├── leadUnit ................. UNIT
│   ├── awardStatus .............. AWARD_STATUS
│   ├── awardType ................ AWARD_TYPE
│   ├── activityType ............. ACTIVITY_TYPE
│   ├── awardTransactionType ..... AWARD_TRANSACTION_TYPE
│   ├── awardBasisOfPayment ...... AWARD_BASIS_OF_PAYMENT
│   ├── awardMethodOfPayment ..... AWARD_METHOD_OF_PAYMENT
│   └── nsfCodeBo ................ NSF_CODES
│
└── ONE_TO_MANY (each its own dataset — never flattened into the root)
    ├── projectPersons ........... AWARD_PERSONS ............ 345,596
    │   ├── units ................ AWARD_PERSON_UNITS ....... 353,105
    │   │   └── unitCreditSplits . AWARD_PERS_UNIT_CRED_SPLITS 197,220
    │   └── creditSplits ......... AWARD_PERSON_CREDIT_SPLITS  216,156
    ├── awardAmountInfos ......... AWARD_AMOUNT_INFO ........ 923,457
    ├── awardDirectFandADistributions AWARD_AMT_FNA_DISTRIBUTION 458,011
    ├── awardSponsorTerms ........ AWARD_SPONSOR_TERM ..... 4,063,797
    ├── awardReportTermItems ..... AWARD_REPORT_TERMS ....... 839,095
    │   └── awardReportTermRecipients AWARD_REP_TERMS_RECNT ......... 0
    ├── specialReviews ........... AWARD_SPECIAL_REVIEW ..... 134,513
    │   └── specialReviewExemptions AWARD_EXEMPT_NUMBER ........ 2,684
    ├── awardCustomDataList ...... AWARD_CUSTOM_DATA ...... 6,930,491
    ├── awardCloseoutItems ....... AWARD_CLOSEOUT ......... 1,265,423
    ├── awardComments ............ AWARD_COMMENT .......... 2,595,983
    ├── awardAttachments ......... AWARD_ATTACHMENT ....... 1,861,982
    ├── awardCfdas ............... AWARD_CFDA ............... 187,993
    ├── awardUnitContacts ........ AWARD_UNIT_CONTACTS ...... 386,214
    ├── currentVersionBudgets .... AWARD_BUDGET_EXT .......... 80,248
    │   └── budgetPeriods ........ AWARD_BUDGET_PERIOD_EXT ... 84,965
    ├── awardBudgetLimits ........ AWARD_BUDGET_LIMIT ........ 63,051
    ├── fundingProposals ......... AWARD_FUNDING_PROPOSALS ... 13,657
    ├── awardApprovedSubawards ... AWARD_APPROVED_SUBAWARDS ... 9,336
    ├── awardCostShares .......... AWARD_COST_SHARE ........... 7,618
    ├── awardHierarchy ........... AWARD_HIERARCHY ........... 43,239   (on AWARD_NUMBER)
    ├── awardNotepads ............ AWARD_NOTEPAD ................. 34
    ├── sponsorContacts .......... AWARD_SPONSOR_CONTACTS ........ 16
    ├── awardFandaRate ........... AWARD_IDC_RATE ................ 10
    ├── approvedEquipmentItems ... AWARD_APPROVED_EQUIPMENT ....... 3
    ├── paymentScheduleItems ..... AWARD_PAYMENT_SCHEDULE ......... 3
    ├── keywords ................. AWARD_SCIENCE_KEYWORD .......... 0  (empty at BU)
    ├── approvedForeignTravelTrips AWARD_APPROVED_FOREIGN_TRAVEL .. 0  (empty at BU)
    └── awardTransferringSponsors  AWARD_TRANSFERRING_SPONSOR ..... 0  (empty at BU)
```

## Relationships that do not follow the AWARD_ID pattern

These are the ones most likely to be mis-joined, so they are called out explicitly:

| Relationship | Join | Why it differs |
|---|---|---|
| `awardHierarchy` | `AWARD_HIERARCHY.AWARD_NUMBER = AWARD.AWARD_NUMBER` | Hierarchy is **version-independent** — it describes the award, not a sequence. Not declared as an OJB collection; KC navigates it via `AwardHierarchyService`. Added to the graph explicitly, not inferred. |
| `AwardPerson.units` / `.creditSplits` | `AWARD_PERSON_UNITS.AWARD_PERSON_ID = AWARD_PERSONS.AWARD_PERSON_ID` | Keys on the **person row**, not the award. The Java property is `awardContactId` but the column is `AWARD_PERSON_ID` — a name mismatch that would be easy to get wrong. |
| `AwardPersonUnit.unitCreditSplits` | `AWARD_PERS_UNIT_CRED_SPLITS.AWARD_PERSON_UNIT_ID` | Third level down: award → person → unit → credit split. |
| `AwardSpecialReview.specialReviewExemptions` | `AWARD_EXEMPT_NUMBER.AWARD_SPECIAL_REVIEW_ID` | Keys on the special-review row. |
| `syncStatuses` | `parentAwardId` | Points at the **parent** award in a hierarchy, not the owning award. Excluded anyway. |

## Excluded relationships

| Relationship | Table | Reason |
|---|---|---|
| `awardDocument` | `AWARD_DOCUMENT` | KEW workflow routing header — platform infrastructure, not Grants data |
| `versionHistory` | `VERSION_HISTORY` | Framework versioning bookkeeping; no declared FK |
| `awardTemplate` | `AWARD_TEMPLATE` | Authoring template the record was created from, not award content |
| `allFundingProposals` | `AWARD_FUNDING_PROPOSALS` | Duplicate of `fundingProposals` with no inverse FK declared |
| `syncChanges` / `syncStatuses` | `AWARD_SYNC_*` | Hierarchy sync operational log; both empty at BU |
| `awardNotifications` | `AWARD_NOTIFICATION` | Notification send log; operational (2 rows) |
| `awardCgbList` | `AWARD_CGB` | Contracts & Grants Billing configuration (154,701 rows) — BU billing operations rather than award content. **Confirm with BU** whether Huron needs it |
| 4 × `MANY_TO_ONE_INVERSE` | `AWARD` | Inverse navigation handles (`AwardPerson.award` etc.); the child datasets already carry `AWARD_ID` / `AWARD_NUMBER` |

Empty-at-BU collections (`keywords`, `approvedForeignTravelTrips`, `awardTransferringSponsors`,
`awardReportTermRecipients`) are **kept in the graph** — a field mapper still benefits from
knowing the structure exists — but they will produce no rows.

## BU-specific parts of the graph

| Item | What it is |
|---|---|
| `AWARD_EXTENSION` (31 cols, 1:1) | BU's extended award attributes. Includes `GRANT_NUMBER`, `PRIME_SPONSOR_AWARD_ID`, `FEDERAL_CLINICAL_TRIAL`, `A133_CLUSTER`, `ARRA_CODE`, `BU_BMC_FA_SPLIT`, `SPUDS_RECORD_NUMBER`, `WALKER_SOURCE_NUMBER`. **Verified against a live BU Award screen** — these render as Grant Number, Prime Sponsor Award ID and Federal Clinical Trial. |
| `AWARD_CUSTOM_DATA` (EAV) | 46 BU-configured custom attributes for Award. The logical field is `CUSTOM_ATTRIBUTE_ID` + its definition; `VALUE` is generic storage and must never be presented as a field name. |
| `AWARD_CGB` | Contracts & Grants Billing — a KC module BU populates heavily (154,701 rows); excluded pending confirmation. |
| `SPUDS_RECORD_NUMBER`, `WALKER_SOURCE_NUMBER`, `BU_BMC_FA_SPLIT` | References to BU-local systems/processes; will need BU explanation for Huron to map them. |

## The personnel sub-graph

Investigators / key personnel are the most heavily related part of the Award graph and
the easiest to map wrongly, so the chain is set out in full:

```
AWARD
 └── AWARD_PERSONS                    (award_id)            345,600 rows
      ├── identity: PERSON_ID  -> KIM person, resolved in Java
      ├── identity: ROLODEX_ID -> ROLODEX, joinable
      ├── role:     CONTACT_ROLE_CODE -> EPS_PROP_PERSON_ROLE
      ├── AWARD_PERSON_UNITS          (award_person_id)     353,109 rows
      │    └── AWARD_PERS_UNIT_CRED_SPLITS (award_person_unit_id) 198,930 rows
      │         └── INV_CREDIT_TYPE
      └── AWARD_PERSON_CREDIT_SPLITS  (award_person_id)     216,160 rows
           └── INV_CREDIT_TYPE
```

Four findings that matter for mapping:

**1. A person has two possible identities, and only one of them is joinable.**
`AwardContact` (the parent of `AwardPerson`) holds `personId`, `rolodexId`, `person`
and `rolodex`. There is **no OJB or JPA relationship from `AWARD_PERSONS` to any person
table** — `person` is a `KcPerson` resolved at runtime by `KcPersonService` from KIM.
`rolodex` resolves from `ROLODEX_ID` against `ROLODEX` and *is* joinable. In production:

| Identity | Rows |
|---|---|
| `PERSON_ID` (KIM person) | 345,133 |
| `ROLODEX_ID` (external contact) | 464 |
| neither | 3 |

`AWARD_PERSONS.FULL_NAME` is a **persisted denormalized copy**, not the system of
record: `AwardContact.getFullName()` calls `getContact()`, which refreshes it from the
person record on read. The interface therefore exposes `PERSON_SOURCE`
(`KIM_PERSON` / `ROLODEX` / `UNIDENTIFIED`) so Huron does not mistake `FULL_NAME` for
authoritative KIM data.

**2. The role lookup silently doubles the dataset.** `CONTACT_ROLE_CODE`
(`COI`, `KP`, `MPI`, `PI`) decodes against `EPS_PROP_PERSON_ROLE` via
`PropAwardPersonRoleService`. That table holds **two rows per code**, one per
`SPONSOR_HIERARCHY_NAME` (`DEFAULT` and `NIH Multiple PI`) — the same code carries
different labels (`PI` is both "Principal Investigator" and "PD/PI Contact"). An
unfiltered join takes the dataset from **345,600 to 691,200 rows**, verified. The
interface pins the join to `SPONSOR_HIERARCHY_NAME = 'DEFAULT'`, which resolves all
345,600 rows with 0 unmatched. Awards under the NIH multiple-PI hierarchy legitimately
carry the other label — reported, not resolved.

**3. Credit splits exist at two levels.** Person-level
(`AWARD_PERSON_CREDIT_SPLITS`, keyed on `AWARD_PERSON_ID`) and unit-level
(`AWARD_PERS_UNIT_CRED_SPLITS`, keyed on `AWARD_PERSON_UNIT_ID`). Both decode against
`INV_CREDIT_TYPE`. The UI renders one column per credit type, which is why the credit
grid is built from JSTL macros rather than fixed field names.

**4. Property names differ from column names.** `AwardPerson.roleCode` →
`CONTACT_ROLE_CODE`, `faculty` → `FACULTY_FLAG`, `includeInCreditAllocation` →
`ADD_CREDIT_SPLIT`, `awardContactId` → `AWARD_PERSON_ID`. The UI form bean adds a
third name for the same field (`contactRoleCode`).

## AWARD_CGB — investigated, recommendation: exclude

`AWARD_CGB` was assessed on evidence rather than on its name.

| Question | Finding |
|---|---|
| Java class | `org.kuali.kra.award.cgb.AwardCgb` — **stock Kuali**, not BU-authored (Kuali, Inc. copyright) |
| ORM mapping | OJB `collection-descriptor` `awardCgbList` on Award, `inverse-foreignkey awardId`; carries `AWARD_ID`, `AWARD_NUMBER`, `SEQUENCE_NUMBER` |
| Relationship | ONE_TO_MANY by declaration, but **1:1 in practice** — 154,705 rows / 154,705 distinct `AWARD_ID` |
| Coverage | 154,705 of 282,468 award versions (~55%) |
| UI | Real panel: `awardCgb.tag`, tab **"Contract And Grants Billing"**, on the Award Payment Reports & Terms screen |
| DataDictionary | Full entry (`AwardCgb.xml`) with 14 labelled fields |
| Business meaning | Contracts & Grants Billing: invoicing configuration (Auto Approve, Invoicing Option, Minimum Invoice Amount, Dunning Campaign, Stop Work, Suspend Invoicing, Letter of Credit Review) plus operational billing state (Last Billed Date, Final Billed Indicator, Amount To Draw, Invoice Document Status) |

So the structure is legitimate: a real, stock Award child collection with a real UI and
real labels. On structure alone it would qualify for exposure.

**The production data decides it.** Of the 14 business fields:

| Field | Populated | Distinct values |
|---|---|---|
| `MIN_INVOICE_AMT`, `INVOICING_OPTION`, `DUNNING_CAMPAIGN_ID`, `LAST_BILLED_DATE`, `AMT_TO_DRAW`, `INVOICE_DOCUMENT_STATUS`, `LOC_CREATION_TYPE` | **0 rows** | — |
| `ADDITIONAL_FORMS_REQ`, `AUTO_APPROVE_INVOICE`, `STOP_WORK`, `FINAL_BILL`, `LETTER_OF_CREDIT_REVIEW`, `SUSPEND_INVOICING` | 154,705 rows | **`'N'` only — one value, zero variance** |

Seven fields are entirely empty; the other six are `'N'` on every single row. The table
contains **no information**: the rows are defaults written when the award was created,
and no user has ever set a value.

**Recommendation: exclude.** Not because it is "billing", but because it carries zero
business signal at BU — every field is either NULL or a constant. Migrating it would
move 154,705 rows of defaults into HRS and give Huron's mapper 14 fields with nothing
to infer meaning from. If BU intends to *start* using Contracts & Grants Billing in
HRS, that is a configuration decision for the new system, not a data conversion.

`HURON_EXPOSE = N` in `AWARD_GRAPH.csv`, reason recorded.

## Design rules for the SQL interface

1. **No giant flat join.** One-to-many collections are never joined into the root. A single
   award version with 5 persons × 12 sponsor terms × 40 custom attributes would otherwise
   produce 2,400 duplicate award rows.
2. **Many-to-one descriptive relationships are folded into the root**, exposing both the
   source code and its description (`STATUS_CODE` + `STATUS_DESCRIPTION`). These cannot
   multiply rows.
3. **Every child dataset carries `AWARD_ID`, `AWARD_NUMBER` and `SEQUENCE_NUMBER`** plus its
   own primary key, so Huron can reassemble the graph and tie each child to the correct
   award version.
4. **Nothing is filtered to a final migration population**, and historical anomalies are
   reported rather than resolved.

## Verification

- `AWARD_EXTENSION` confirmed 1:1: 282,468 rows / 282,468 distinct `AWARD_ID`.
- All root lookup joins verified against production datatypes; three require conversion
  (`STATUS_CODE` and `ACTIVITY_TYPE_CODE` need `TO_CHAR`, `TRANSACTION_TYPE_CODE` needs
  `TO_NUMBER` and is safe — 0 non-numeric values).
- Unmatched lookup codes (reported, not resolved): `transaction_type_code` 15 rows,
  `sponsor_code` 3, `prime_sponsor_code` 6.
