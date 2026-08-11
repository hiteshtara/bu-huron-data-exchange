# BU / Huron review items

The questions BU would like to work through with Huron, grouped by business object.

This is a meeting document, not a full record. Each item gives the decision needed, why it
matters, the few numbers required to discuss it, where BU currently stands, and a link to
the evidence. The detail deliberately stays where it belongs:

| Document | What it holds |
|---|---|
| This file | What BU and Huron need to decide together |
| [docs/DECISION_REGISTER.md](../docs/DECISION_REGISTER.md) | The complete internal decision and anomaly record |
| `modules/<object>/*_GRAPH.md` | Evidence and technical reasoning behind every item |

Counts were measured against KCOEUS production on 2026-08-07
([provenance](../docs/PROVENANCE.md)). See
[HURON_MAPPING_GUIDE.md](../HURON_MAPPING_GUIDE.md) for what BU prepared and how it is
organised.

## Summary

| # | Object | Decision needed | Priority |
|---|---|---|---|
| D-18 | Delivery | How should Huron receive BU's curated datasets? | **High** |
| D-20 | All | How will Huron hold KC source keys and the source-to-Huron ID crosswalk? | **High** |
| D-21 | All | What KC history, if any, migrates alongside the current record? | **High** |
| D-17 | Award | Grain: Award family, Award/account, or both? | **High** |
| D-01 | Subaward | Historical or current Award version on a funding link? | **High** |
| D-08 | Negotiation | Is it expected that 78% are attached to nothing? | **High** |
| D-02 | Award | Is Contracts & Grants Billing in migration scope? | Medium |
| D-03 | Proposal | Confirm Proposal Development is unused before sizing it | Medium |
| D-05 | Proposal | Are intake-only proposal logs in migration scope? | Medium |
| D-10 | Subaward | Are the near-empty subaward features expected HRS areas? | Medium |
| D-09 | Negotiation | So few links to Proposal and Subaward — is that right? | Medium |
| D-07 | Proposal | Values on a module the attribute is not configured for | Low |
| D-11 | All three | Configured custom attributes that were never populated | Low |

---

## Delivery

### D-18 — How should Huron receive BU's curated datasets? · **High**

BU has finished the logical source interface — the curated SQL under
`modules/award/sql/` and its equivalents for the other three objects. What is not decided
is the physical delivery method: whether Huron consumes those datasets as files, as
tables in a BU-controlled staging schema, through read-only database access to curated
views, or through an API or managed transfer.

**Why it matters.** It determines what BU has to provision, how long that takes, and
whether extracts need to be repeatable for mock conversions and cutover. It also has a
security-approval path on the BU side that is worth starting early rather than late.

**Where BU stands.** No commitment. We would rather agree the approach than build a
delivery mechanism that turns out to be the wrong shape for Huron's tooling. The module
SQL stays the contract regardless — how the results travel should not change what any
column means.

**Evidence:** [docs/HURON_CONNECTIVITY.md](../docs/HURON_CONNECTIVITY.md) sets out the
four options with their trade-offs, and the specific questions BU needs answered to move
this forward.

---

## Across all four objects

### D-20 — How will Huron hold KC source keys and the ID crosswalk? · **High**

Every dataset BU exposes carries its business key (`AWARD_NUMBER`, `PROPOSAL_NUMBER`,
`SUBAWARD_CODE`, `NEGOTIATION_ID`) and the internal keys needed to reassemble the graph.
What we would like to agree is what happens to them on the Huron side.

Dean framed the problem:

> Various objects are linked in the current Kuali (e.g., Proposals to Awards, Subawards to
> Awards). Obviously, these objects link today using the Kuali-based keys. We know when an
> object is converted over to Huron, it will no longer carry the Kuali-native object key.
> It will be assigned a key native to Huron. This is where it will be important to include
> an original source key in any of the converted data.

**The decision.** Which Huron field or structure holds the KC source key, and where does
the record-level crosswalk live — one row per converted object, KC key to Huron id?

**Why it matters.** After load, the source key is the only thing tying a converted record
back to KC. It is what re-links objects that were related in KC once Huron has assigned
its own identifiers, and it is what makes reconciliation possible at all.

**Where BU stands.** That the keys must be preserved is not in question — the data
contract states it as a requirement. BU has not built a crosswalk, because the Huron half
of every row does not exist until load.

**Evidence:** [docs/DATA_CONTRACT.md](../docs/DATA_CONTRACT.md), "Source keys have to
survive the migration" and "The source-to-Huron ID crosswalk".

### D-21 — What KC history, if any, migrates? · **High**

The datasets BU exposes contain the selected current record for each business object.
Historical KC versions still exist as source data — `AWARD` holds 282,468 physical rows
behind 43,202 current ones — but they are not the default migration root.

**The decision.** Is migration scope the current record only, the current record plus
selected historical versions, historical versions represented as documents or reference
material, or another history mechanism HRS supports?

**Why it matters.** It changes the volume of the conversion, and it decides what "history"
means to a BU user after go-live.

**Where BU stands.** No position, and we are not deciding it. Exposing history is not the
obstacle — removing the version join does it. Dean's understanding is that Huron history
is structurally different from KC's and may appear as document-style history rather than
prior object versions; we have recorded that as his observation rather than something this
repository has verified.

**Evidence:** [docs/DATA_CONTRACT.md](../docs/DATA_CONTRACT.md), "Current versus
historical".

---

## Award

### D-17 — What grain does HRS expect? · **High**

BU's awards are not flat. An **Award family** — what BU has historically called a grant
family — is a root `-00001` award together with its child/subaccount awards, and each of
those awards separately has its own sequence/version history:

```
Award family
    └── root / main Award        123456-00001
            ├── child Award      123456-00002     a separate account
            ├── child Award      123456-00003     a separate account
            └── child Award      123456-00004
                    └── child Award  123456-00005  occasional deeper nesting
```

| | |
|---|---|
| Award families | 15,729 |
| Award/account business records | 43,202 |
| Non-root Award/accounts | 27,472 |
| Families holding a single Award | 199 |

**The decision.** Does HRS expect the Award family as the primary migrated object, each
Award/account as the primary object, or both as separate related objects?

If the answer is family-level, we would also like to agree how a family is identified:
`ROOT_AWARD_NUMBER`, `BU_GRANT_NUMBER`, or an HRS identifier with both of ours kept as
source identifiers. `BU_GRANT_NUMBER` is never ambiguous within a family — 14,447 families
hold exactly one value and none holds more — but 1,282 families have no value at all.

**Why it matters.** It sets the grain of the whole Award migration, and it determines how
child awards, hierarchy relationships, account numbers and `BU_GRANT_NUMBER` are
represented. Until it is answered, some downstream mapping decisions are premature.

**Where BU stands.** No position. We are **not** proposing to derive or backfill the 1,282
missing `BU_GRANT_NUMBER` values — that is part of this decision. Dean independently raised the
same target-model question — "How are the Kuali Award Parent / Child records going to be
mapped" — which is what the numbers above quantify.

**Evidence:** [modules/award/AWARD_GRAPH.md](../modules/award/AWARD_GRAPH.md), "Award
families".

### D-02 — Is Contracts & Grants Billing in migration scope? · Medium

`AWARD_CGB` holds 154,705 rows of C&G Billing configuration.

**Why it matters.** It is 154,705 rows either way, and excluding it is a scope decision
rather than a technical one.

**Where BU stands.** Excluded from the Award graph, on evidence rather than on the table's
name — the table carries no information we could map. We would like that confirmed.

**Evidence:** [modules/award/AWARD_GRAPH.md](../modules/award/AWARD_GRAPH.md),
"AWARD_CGB — investigated, recommendation: exclude".

---

## Institutional Proposal

### D-03 — Confirm Proposal Development is unused · Medium

`EPS_PROPOSAL` holds 1 row against 130,122 Institutional Proposals.

**Why it matters.** If BU never adopted KC's Proposal Development module, Huron should not
size a conversion for it.

**Where BU stands.** It looks unused, but we would rather have it confirmed than assume.

**Evidence:** [modules/proposal/PROPOSAL_GRAPH.md](../modules/proposal/PROPOSAL_GRAPH.md).

### D-05 — Are intake-only proposal logs in migration scope? · Medium

1,136 `PROPOSAL_LOG` records never became Institutional Proposals.

**Why it matters.** If HRS has a concept for pre-proposal intake they may belong there; if
not, they may not convert at all.

**Where BU stands.** They are intake records that stopped short, not defects. We left them
outside the Institutional Proposal graph and took no view on scope.

**Evidence:** [modules/proposal/PROPOSAL_GRAPH.md](../modules/proposal/PROPOSAL_GRAPH.md),
"Four relationships we had to dig into".

### D-07 — Values on a module the attribute is not configured for · Low

Custom attributes 1212 ("Contract") and 1213 ("Billing Agreement") hold Institutional
Proposal values, but `CUSTOM_ATTRIBUTE_DOCUMENT` does not configure them for `INPR`.

**Why it matters.** How HRS should treat values whose configuration disagrees with where
they appear.

**Where BU stands.** We expose the values and flag the mismatch with a NULL
`APPLIES_TO_DOCUMENT_TYPE`, rather than dropping real values because a configuration row
disagrees.

**Evidence:** [modules/proposal/PROPOSAL_GRAPH.md](../modules/proposal/PROPOSAL_GRAPH.md),
"Custom-attribute anomalies".

---

## Subaward

Dean asked the broader question directly — "How are Subaward objects going to be mapped" —
and the two items below are how that breaks down against what we found in production. They
are the concrete source-model decisions behind it, not a substitute for the wider mapping
conversation.

One thing worth separating before that conversation: a Subaward is not the same thing as a
child/subaccount Award. See [docs/DATA_MODEL.md](../docs/DATA_MODEL.md), "A child Award is
not a Subaward".

### D-01 — Historical or current Award version on a funding link? · **High**

`SUBAWARD_FUNDING_SOURCE` records the specific Award **version** that funded a subaward at
the time. **5,846 of 7,930 funding rows (74%) point at a version that has since been
superseded.**

**The decision.** On load, should HRS preserve the historically referenced Award version,
associate the subaward with the current Award/account, or carry both?

**Why it matters.** It changes what a subaward is attached to in HRS.

**Where BU stands.** We preserved what KC recorded rather than silently repointing, and
added `FUNDING_AWARD_VERSION_IS_CURRENT` and `CURRENT_AWARD_ID` so either reading is
available without losing the original. We have not chosen between them.

**Evidence:** [modules/subaward/SUBAWARD_GRAPH.md](../modules/subaward/SUBAWARD_GRAPH.md),
"How Subaward connects to Award".

### D-10 — Are the near-empty subaward features expected HRS areas? · Medium

`SUBAWARD_AMT_RELEASED` holds 2 rows; `SUBAWARD_CLOSEOUT`, `SUBAWARD_REPORTS` and
`SUBAWARD_TEMPLATE_ATTACHMENTS` are empty.

**Why it matters.** If HRS expects invoice tracking, closeout or subaward reporting to
arrive with data, it is kept somewhere else at BU and we should go looking for it.

**Where BU stands.** Kept in the graph because the structure is useful when mapping, but
they will produce almost no rows.

**Evidence:** [modules/subaward/SUBAWARD_GRAPH.md](../modules/subaward/SUBAWARD_GRAPH.md),
"Things we still need to confirm".

---

## Negotiation

### D-08 — Is it expected that 78% are attached to nothing? · **High**

9,249 of 11,842 negotiations have no associated Award, Institutional Proposal or Subaward,
and carry free-standing detail in `NEGOTIATION_UNASSOC_DETAIL` instead.

**The decision.** Is that the intended business behaviour, or were these negotiations never
linked back once the award arrived?

**Why it matters.** It affects how the majority of negotiations map.

**Where BU stands.** The structure is legitimate — KC provides it for exactly this case —
but the data cannot tell us whether it is intended.

**Evidence:**
[modules/negotiation/NEGOTIATION_GRAPH.md](../modules/negotiation/NEGOTIATION_GRAPH.md),
"Negotiations that are not attached to anything".

### D-09 — So few links to Proposal and Subaward · Medium

Only **3** negotiations associate to an Institutional Proposal and **16** to a Subaward,
against 11,842 negotiations.

**Why it matters.** If associations were recorded differently in practice, mapping those
two paths on 3 and 16 records would be building on very little.

**Where BU stands.** No concern found in the data. We would like a sanity check with the
business office before mapping.

**Evidence:**
[modules/negotiation/NEGOTIATION_GRAPH.md](../modules/negotiation/NEGOTIATION_GRAPH.md),
"What a Negotiation is attached to".

---

## All three modules

### D-11 — Configured custom attributes that were never populated · Low

Some BU custom attributes have value rows where every value is NULL: **6** on Institutional
Proposal, **2** on Negotiation, **1** on Subaward.

**Why it matters.** Whether they matter to HRS as configuration, or whether only populated
fields are of interest.

**Where BU stands.** Kept in the field dictionary marked
`NO_POPULATED_VALUES_IN_PRODUCTION`, because they describe fields BU configured. We did not
drop them.

**Evidence:** [reference/KUALI_FIELD_DICTIONARY.csv](KUALI_FIELD_DICTIONARY.csv) and each
module's `*_GRAPH.md`.

---

## What is deliberately not in this list

BU is handling these on its own, so this list stays about decisions rather than data
cleanup. All are recorded in [docs/DECISION_REGISTER.md](../docs/DECISION_REGISTER.md) with
the evidence in the module graph documents.

Award hierarchy anomalies (D-13, D-14, D-15), 16 non-leaf Awards holding an account number
(D-16), a legacy proposal identifier that resolves to nothing (D-06), 1,895,754
`EPS_PROP_RATES` rows whose owning module is unclear (D-04), and unresolved UI labels on
technical `ORGANIZATION` / `UNIT` columns (D-12).

If any of them turns out to affect a migration decision, we will move it up into this list
rather than leave it buried.
