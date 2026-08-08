# KC Award Business-Object Graph

## Where this graph came from

Huron works with a business object as a whole graph, not a single table, so before we
could expose Awards as SQL we had to work out what actually makes up an Award in KC. We
built it from the KC model rather than guessing from table names.

We used two sources together:

1. **`~/Downloads/kuali-research-bu-master`** (BU's fork, branch `bu-master`, read-only) —
   the OJB class descriptor for `org.kuali.kra.award.home.Award` in
   `coeus-impl/src/main/resources/org/kuali/kra/award/repository-award.xml`.
   - `<reference-descriptor>` → `MANY_TO_ONE` (or `ONE_TO_ONE`)
   - `<collection-descriptor>` → `ONE_TO_MANY`
2. **KCOEUS production** — every child class resolved to a real table, annotated with its
   actual `COUNT(*)`, so the graph reflects what BU holds, not what KC supports.

We build it with `scripts/build_object_graph.py --module award`. `AWARD_GRAPH.csv` is
the machine-readable version.

**108 relationships** discovered: 53 `MANY_TO_ONE`, 41 `ONE_TO_MANY`, 1 `ONE_TO_ONE`,
13 `MANY_TO_ONE_INVERSE`. 87 proposed for exposure, 21 excluded.

> Regenerated after two graph-builder defects found during the Institutional Proposal
> work: expansion stopped at two levels (dropping `AwardPersonUnit.creditSplits`), and
> children with only references — never collections — were not expanded at all. The
> Award *findings* were unaffected: both relationships were already documented below and
> covered by `sql/huron_award_person_unit_credit_split.sql`; only the machine-readable
> CSV was incomplete.

## Root object

| | |
|---|---|
| Java class | `org.kuali.kra.award.home.Award` |
| Root table | `KCOEUS.AWARD` (57 columns, 282,468 rows) |
| Primary key | `AWARD_ID` |
| Business key | `AWARD_NUMBER` + `SEQUENCE_NUMBER` |

Award is versioned. One `AWARD_NUMBER` has many sequences, each its own `AWARD_ID` row,
so 282,468 rows are only 43,202 awards.

Every child collection keys on `AWARD_ID`, which means a child belongs to one specific
award version rather than to the award as a whole. The exceptions are called out below.

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
    │   │   └── unitCreditSplits . AWARD_PERS_UNIT_CRED_SPLITS 198,926
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

## Relationships that do not key on AWARD_ID

These are the ones most likely to be joined wrongly, so they are worth stating plainly:

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

**A person has two possible identities, and only one of them is joinable.**
`AwardContact`, the parent of `AwardPerson`, holds `personId`, `rolodexId`, `person` and
`rolodex`. There is no ORM relationship from `AWARD_PERSONS` to any person table at all —
`person` is a `KcPerson` that KC resolves at runtime through `KcPersonService`. `rolodex`
does resolve against `ROLODEX` and is joinable. In production:

| Identity | Rows |
|---|---|
| `PERSON_ID` (KIM person) | 345,133 |
| `ROLODEX_ID` (external contact) | 464 |
| neither | 3 |

`AWARD_PERSONS.FULL_NAME` is a stored copy rather than the system of record —
`AwardContact.getFullName()` calls `getContact()`, which refreshes it from the person
record every time it is read. We expose `PERSON_SOURCE` (`KIM_PERSON`, `ROLODEX` or
`UNIDENTIFIED`) so it is obvious which identity a row actually has.

**The role lookup doubles the dataset if you let it.** `CONTACT_ROLE_CODE` (`COI`, `KP`,
`MPI`, `PI`) decodes against `EPS_PROP_PERSON_ROLE`, which KC reaches through
`PropAwardPersonRoleService`. That table holds two rows for every code, one per
`SPONSOR_HIERARCHY_NAME` — `DEFAULT` and `NIH Multiple PI` — and the same code carries a
different label in each. `PI` is both "Principal Investigator" and "PD/PI Contact".

We checked what an unfiltered join does: 345,600 rows become 691,200. We pin the join to
the `DEFAULT` hierarchy, which resolves all 345,600 with nothing unmatched. Awards under
the NIH multiple-PI hierarchy genuinely carry the other label, and we left that alone.

**Credit splits exist at two levels.** There is a person-level split
(`AWARD_PERSON_CREDIT_SPLITS`, keyed on `AWARD_PERSON_ID`) and a unit-level one
(`AWARD_PERS_UNIT_CRED_SPLITS`, keyed on `AWARD_PERSON_UNIT_ID`). Both decode against
`INV_CREDIT_TYPE`. The screen renders one column per credit type, which is why that part
of the UI is built from JSTL macros instead of fixed field names.

**Property names and column names drift apart here.** `AwardPerson.roleCode` is
`CONTACT_ROLE_CODE`, `faculty` is `FACULTY_FLAG`, `includeInCreditAllocation` is
`ADD_CREDIT_SPLIT`, and `awardContactId` is `AWARD_PERSON_ID`. The UI form bean then adds
a third name for the same field, `contactRoleCode`.

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

On structure alone this would qualify: a real stock Award child collection with a real
UI panel and real labels.

The production data is what settled it. Of the 14 business fields:

| Field | Populated | Distinct values |
|---|---|---|
| `MIN_INVOICE_AMT`, `INVOICING_OPTION`, `DUNNING_CAMPAIGN_ID`, `LAST_BILLED_DATE`, `AMT_TO_DRAW`, `INVOICE_DOCUMENT_STATUS`, `LOC_CREATION_TYPE` | **0 rows** | — |
| `ADDITIONAL_FORMS_REQ`, `AUTO_APPROVE_INVOICE`, `STOP_WORK`, `FINAL_BILL`, `LETTER_OF_CREDIT_REVIEW`, `SUSPEND_INVOICING` | 154,705 rows | **`'N'` only — one value, zero variance** |

Seven fields are empty and the other six are `'N'` on every row. The table holds no
information — the rows are defaults written when each award was created and nobody has
ever set a value.

So we excluded it. Not because it is billing, but because every field is either NULL or a
constant. Migrating it would move 154,705 rows of defaults into HRS and give the mapper
14 fields with nothing to work from. If BU wants to start using Contracts & Grants
Billing in HRS, that is a configuration decision in the new system rather than something
to convert.

`AWARD_GRAPH.csv` records `HURON_EXPOSE = N` with the reason.

## Why the queries are shaped this way

We keep one-to-many collections in their own queries. One award version with 5 people,
12 sponsor terms and 40 custom attributes would otherwise come back as 2,400 duplicate
award rows.

Many-to-one lookups go into the root, with both the code and its description
(`STATUS_CODE` and `STATUS_DESCRIPTION`), because a lookup cannot multiply rows.

Every child dataset carries `AWARD_ID`, `AWARD_NUMBER` and `SEQUENCE_NUMBER` alongside
its own key, so the graph can be put back together against the right award version.

We did not filter anything down to a final migration population, and where we found
historical oddities we reported them instead of cleaning them up.

## What we checked

`AWARD_EXTENSION` is 1:1 — 282,468 rows against 282,468 distinct `AWARD_ID`.

We checked every root lookup against production datatypes. Three need conversion:
`STATUS_CODE` and `ACTIVITY_TYPE_CODE` need `TO_CHAR`, and `TRANSACTION_TYPE_CODE` needs
`TO_NUMBER`, which is safe because none of its values are non-numeric.

A few codes do not resolve, and we left them alone rather than inventing a fix:
`transaction_type_code` on 15 rows, `sponsor_code` on 3, `prime_sponsor_code` on 6.
