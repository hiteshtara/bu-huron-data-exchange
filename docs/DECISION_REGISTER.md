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

## How this connects to the modules

Each module's `*_GRAPH.md` still explains the finding in context — that is where the
evidence lives. This table is for tracking the answer.

| Module | Findings | IDs |
|---|---|---|
| [Award](../modules/award/AWARD_GRAPH.md) | 6 | D-02, D-12, D-13, D-14, D-15, D-16 |
| [Institutional Proposal](../modules/proposal/PROPOSAL_GRAPH.md) | 5 | D-03 … D-07 |
| [Subaward](../modules/subaward/SUBAWARD_GRAPH.md) | 2 | D-01, D-10 |
| [Negotiation](../modules/negotiation/NEGOTIATION_GRAPH.md) | 2 | D-08, D-09 |
| Cross-module | 1 | D-11 |

## The two to settle first

**D-01** and **D-08** are the ones that change what data means rather than how much of it
there is. D-01 decides what a subaward is attached to in HRS. D-08 covers 78% of all
negotiations. The rest can wait for conversion planning.
