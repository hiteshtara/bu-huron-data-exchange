# Open questions and decisions

Every module ends with a few things we found but deliberately did not fix. They were
scattered across four `*_GRAPH.md` files, which made them hard to work through in a
meeting. This is the single list.

Nothing here is a defect. These are questions about migration scope, historical data or
BU business practice — the kind of thing that needs a person, not a query.

Counts measured 2026-08-07 ([provenance](PROVENANCE.md)).

## Status values

| Status | Meaning |
|---|---|
| Open | Nobody has looked at it yet |
| In review | Being discussed |
| Decided | Answer agreed and recorded in the Decision column |
| Deferred | Not needed before mapping; revisit at conversion |

## The register

| ID | Module | Question | Impact | Owner | Status | Decision |
|---|---|---|---|---|---|---|
| D-01 | Subaward | When a subaward's funding link points at a superseded award version, does the migration load that historical version or associate the subaward with the current award? 5,846 of 7,930 funding rows (74%) point at a superseded version. | **High** — changes what a subaward is attached to in HRS | BU + Huron | Open | |
| D-02 | Award | `AWARD_CGB` is excluded. 7 of its 14 business fields are entirely NULL and the other 6 are `'N'` on all 154,705 rows. Confirm BU does not need Contracts & Grants Billing carried across. | Medium — 154,705 rows either way | BU | Open | |
| D-03 | Proposal | Proposal Development looks unused: `EPS_PROPOSAL` holds 1 row against 130,122 Institutional Proposals. Confirm so Huron does not size a conversion for it. | Medium — scope of a whole KC module | BU | Open | |
| D-04 | Proposal | `EPS_PROP_RATES` holds 1,895,754 rows even though Proposal Development is empty. Which module owns those rate rows? | Medium | BU | Open | |
| D-05 | Proposal | 1,136 proposal logs never became Institutional Proposals. In or out of migration scope? | Medium | BU + Huron | Open | |
| D-06 | Proposal | `PROPOSAL_LOG.INST_PROPOSAL_NUMBER` is populated on 30,646 rows but matches no proposal. Legacy COEUS identifier — does it need to come across as a cross-reference? | Low | BU | Open | |
| D-07 | Proposal | Custom attributes 1212 ("Contract") and 1213 ("Billing Agreement") hold Institutional Proposal values but are not configured for `INPR`. Values are exposed with the mismatch flagged. | Low | BU | Open | |
| D-08 | Negotiation | 9,249 of 11,842 negotiations (78%) are not associated with an Award, Proposal or Subaward. Expected, or were they never linked back once the award arrived? | **High** — affects how most negotiations map | BU | Open | |
| D-09 | Negotiation | Only 3 negotiations link to an Institutional Proposal and 16 to a Subaward. Small enough to be worth a sanity check with the office. | Medium | BU | Open | |
| D-10 | Subaward | `SUBAWARD_AMT_RELEASED` holds 2 rows in the whole table; `SUBAWARD_CLOSEOUT`, `SUBAWARD_REPORTS` and `SUBAWARD_TEMPLATE_ATTACHMENTS` are empty. Unused KC features, or is the information kept elsewhere? | Medium | BU | Open | |
| D-11 | All | Custom attributes with rows but no non-NULL values anywhere: 6 on `INPR`, 2 on `NGT`, 1 on `SAWD`. They are marked `NO_POPULATED_VALUES_IN_PRODUCTION` in the field dictionary. Configuration worth keeping, or drop them? | Low | BU + Huron | Open | |
| D-12 | Award | `ORGANIZATION` (37 of 41 columns) and `UNIT` (5 of 9) resolve UI labels; the rest are technical columns. Confirm no label is expected for those. | Low | BU | Open | |
| D-13 | Award | Two awards exist in `AWARD` with no `AWARD_HIERARCHY` row at all — `200086-00008` and `211654-00003`. They belong to no family. We did not place them by reading their numbers. Should they be attached to a family, or do they convert standalone? | Low | BU | Open | |
| D-14 | Award | `204946-00004` appears in `AWARD_HIERARCHY` but not in `AWARD`. | Low | BU | Open | |
| D-15 | Award | 30 award numbers have hierarchy rows that differ only by the `ACTIVE` flag, and 2 of those (`200431-00004`, `201514-00005`) also disagree about the parent. We take the active placement. Confirm that is the intended current structure. | Low | BU | Open | |
| D-16 | Award | BU's 2012 KCRM-SAP specification says an account number may only sit on an award with no children, and that it must be handed down if that award later gains children. 16 non-leaf awards still hold one. Stale from before a re-parenting, or meaningful? | Low | BU | Open | |
| D-20 | All | How will Huron retain KC source identifiers, and provide the source-to-Huron ID crosswalk needed for lineage, re-linking and reconciliation? That KC source keys must be preserved is not in question — this is about where they live in the target and who maintains the crosswalk. Detail below. | **High** — without it, converted records cannot be tied back to KC or re-linked to each other | BU + Huron | Open | |
| D-21 | All | What KC history, if any, should be migrated in addition to the selected current business record? The interface exposes the current record; historical physical versions remain source data. Detail below. | **High** — 282,468 physical Award rows against 43,202 current ones, and the same pattern in Proposal and Subaward | BU + Huron | Open | |
| D-19 | Internal access / security | Should BU provision a dedicated database-enforced read-only identity for running the migration and discovery queries, instead of relying only on the client-side read-only controls in the repository runner? A least-privilege identity would make the boundary independent of which client executes the query. Internal BU access management — **not** a prerequisite for documenting Huron's mapping, and no specific privilege design is proposed yet. | Medium — internal posture, no effect on the datasets | BU | Open | |
| D-18 | Delivery | What physical delivery/connectivity method should Huron use to consume BU's curated migration datasets? The logical source interface is complete; how the datasets cross the BU/Huron boundary is not decided. Detail below. | **High** — gates provisioning, security approval and how every extract cycle works | BU + Huron | Open | |
| D-17 | Award | Does HRS expect the Award family, the individual Award/account, or both as distinct objects? This sets the grain of the whole Award migration — 15,729 families against 43,202 awards. Detail below. | **High** — decides what an Award record *is* in HRS | BU + Huron | Open | |

## Source keys and the ID crosswalk (D-20)

**The question.** How will Huron retain KC source identifiers, and provide the
source-to-Huron ID crosswalk needed for lineage, re-linking and reconciliation?

**Not the question.** Whether KC source keys should be preserved. They should, and
[DATA_CONTRACT.md](DATA_CONTRACT.md) now states that as a requirement rather than an
option. What needs agreeing is the target side: which Huron field or structure holds the
source key, and where the record-level crosswalk lives.

**Why it matters.** Dean raised this from the target side:

> Various objects are linked in the current Kuali (e.g., Proposals to Awards, Subawards to
> Awards). Obviously, these objects link today using the Kuali-based keys. We know when an
> object is converted over to Huron, it will no longer carry the Kuali-native object key.
> It will be assigned a key native to Huron. This is where it will be important to include
> an original source key in any of the converted data.

The source key is what re-links converted objects after Huron assigns its own identifiers.
Without it, an Award and the Proposal that became it arrive as unrelated records, and
there is no way to reconcile a load against the source.

**Where BU stands.** Every dataset already carries its business key and its lineage keys,
and the three kinds of identifier are set out in the data contract. BU has not built a
crosswalk table, because the Huron-side half of every row does not exist until load.

**Detail:** [DATA_CONTRACT.md](DATA_CONTRACT.md), "Source keys have to survive the
migration" and "The source-to-Huron ID crosswalk".

## What KC history should be migrated? (D-21)

**The question.** What KC history, if any, should be migrated in addition to the selected
current business record?

**What is true in this repository.** The SQL interface selects the current business record
for each object. Historical physical versions still exist in KC and remain source data;
they are simply not the default migration root. Removing the version join exposes them —
the mechanics are not the obstacle.

**Dean's observation about the target,** which we record as his and have not verified:
Huron history is structurally different from KC history, and may appear as document or
PDF-like history rather than as prior first-class object versions. Nothing in this
repository proves or disproves that; it is a question for Huron.

**What we need decided.** Whether migration scope is:

1. the current record only,
2. the current record plus selected historical versions,
3. historical versions represented as documents or reference material, or
4. another history mechanism Huron supports.

**Why it matters.** `AWARD` holds 282,468 physical rows against 43,202 current records,
and Institutional Proposal and Subaward have the same shape. The answer changes the volume
of the conversion and what "history" means to a BU user after go-live.

**Where BU stands.** No position. We are not deciding this for Huron.

## How will Huron receive the data? (D-18)

Like D-17 this is not a source-system anomaly, so it gets a note here rather than a module
graph document. Unlike D-17 the detail has a proper home —
[docs/HURON_CONNECTIVITY.md](HURON_CONNECTIVITY.md) — so this stays short.

**The question.** What physical delivery/connectivity method should Huron use to consume
BU's curated KC migration datasets?

**Current state.** BU has completed the logical source interface:

```
KCOEUS production
    ↓  BU-controlled read-only migration SQL
Award / Institutional Proposal / Subaward / Negotiation datasets
```

What has not been decided is how those datasets cross the BU/Huron boundary. The
connectivity document sets out four possible models — BU-generated files delivered
securely, Huron read-only access to BU-controlled views, a BU-owned migration staging
schema, or API/managed transfer. **No option is approved.**

**Why it matters.** The delivery decision determines whether Huron needs any database
connectivity to BU at all, whether BU provisions a dedicated read-only account, whether
network and security approvals are needed, whether mock conversions run off files or live
and staged datasets, how repeated extracts and the final cutover data are delivered, and
how reconciliation snapshots are retained. Several of those have lead times, which is why
it is High.

**Do not read the SQL in this repository as evidence that direct database access has been
approved or provisioned.** It has not been. Those files define datasets, not access.

**What we need from Huron.** Confirmation of the source format and connectivity their
migration tooling supports and prefers, including whether Huron pulls the data or BU
pushes it.

## What grain does HRS expect for Awards? (D-17)

This is the one question in the register that changes what the Award migration produces
rather than how much of it there is, so it gets more room than a table cell.

**Award family** (the BU grant family) means the root `-00001` award together with its
child/subaccount awards. We use that term rather than "grant" throughout, because until
this question is answered we do not know what HRS calls its own equivalent object.

### Where BU is today

| | |
|---|---|
| Award/account business records | 43,202 |
| Award families | 15,729 |
| Award/accounts per family | about 2.7 |
| Families that are a root with no children | 199 |

The `-00001` root award is the main award for a family. Child award numbers are separate
accounts or subaccounts under it, and a small number of families nest deeper than that.

`BU_GRANT_NUMBER` behaves as a family-level identifier where it is populated:

| | Families |
|---|---|
| Exactly one distinct `BU_GRANT_NUMBER` | 14,447 |
| More than one | 0 |
| None at all | 1,282 |

So it is clean but not universal. It is never ambiguous within a family, and about 8% of
families have no value.

### What we need decided

Whether HRS expects:

1. the Award family as the primary migrated object,
2. each Award/account as the primary object, or
3. both, as separate related objects.

If HRS maps at the family level, we also need to know what identifies the family:

- `BU_GRANT_NUMBER`, with a strategy for the 1,282 families that have none;
- `ROOT_AWARD_NUMBER`;
- or an HRS identifier, keeping both of ours as source identifiers.

**We are not assuming `BU_GRANT_NUMBER` should be backfilled or derived from
`ROOT_AWARD_NUMBER`.** That is a migration decision, not a data fix, and it is part of
this question rather than something to settle first.

Dean independently raised the same target-model question — "How are the Kuali Award Parent
/ Child records going to be mapped" — which is what this entry quantifies.

### Why it matters

It moves the Award migration grain from 43,202 records to 15,729, and it determines how
child and subaccount awards, hierarchy relationships, account numbers and
`BU_GRANT_NUMBER` are represented in HRS.

### Wording for the meeting

> How should the KC Award hierarchy map to HRS? BU currently has 43,202 Award/account
> records organized into 15,729 Award families — what BU has historically called a grant
> family. The -00001 root Award is the main award, while child Awards represent separate
> accounts/subaccounts. BU_GRANT_NUMBER behaves as a family-level identifier where
> populated, but 1,282 families have no value. We would like to confirm whether HRS
> expects the Award family, individual Award/accounts, or both as distinct objects.

## How this connects to the modules

Each module's `*_GRAPH.md` still explains the finding in context — that is where the
evidence lives. This table is for tracking the answer.

| Module | Findings | IDs |
|---|---|---|
| [Award](../modules/award/AWARD_GRAPH.md) | 7 | D-02, D-12, D-13, D-14, D-15, D-16, D-17 |
| [Institutional Proposal](../modules/proposal/PROPOSAL_GRAPH.md) | 5 | D-03 … D-07 |
| [Subaward](../modules/subaward/SUBAWARD_GRAPH.md) | 2 | D-01, D-10 |
| [Negotiation](../modules/negotiation/NEGOTIATION_GRAPH.md) | 2 | D-08, D-09 |
| Cross-module | 1 | D-11 |
| Delivery / connectivity | 1 | D-18 |
| Internal access / security | 1 | D-19 |
| Cross-cutting migration design | 2 | D-20, D-21 |

## The three to settle first

**D-17**, **D-01** and **D-08** are the ones that change what the data means rather than
how much of it there is. D-17 decides the grain of the Award migration and should come
first, because the answer affects how everything else in the Award module is presented.
D-01 decides what a subaward is attached to in HRS. D-08 covers 78% of all negotiations.
The rest can wait for conversion planning.

**D-20** and **D-21** are also High priority, but they are cross-cutting migration
decisions rather than source-model decisions. D-20 covers how KC source identifiers will be
retained and translated to Huron-native IDs; D-21 covers how much KC history, if any, will
be migrated. D-18 remains a parallel delivery/connectivity decision.

**D-18** runs alongside them on a different track. It does not change what the data
means, but it gates provisioning and security approval, and those have lead times — so
it is worth opening early rather than late.
