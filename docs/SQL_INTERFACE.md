# The read-only SQL interface

Each module has a `sql/` folder that exposes its business object as a set of SELECT
queries. This document explains how those queries are organised and how they fit together,
so a query file can be read on its own without having to reverse-engineer the pattern from
scratch. The relationships and counts behind each dataset are in the module `*_GRAPH.md`
files; this is about the SQL itself.

## What these queries are

Every file under a module's `sql/` folder is a read-only `SELECT`. Nothing here modifies
data. They run against KCOEUS production through the controlled runner, which sets
`SET TRANSACTION READ ONLY` and rejects anything that is not `SELECT`/`WITH`:

```bash
.venv/bin/python scripts/kc_prod_readonly_query.py --file modules/award/sql/huron_award.sql --limit 20
```

The queries return current business records, not a final migration population. We did not
filter anything down to what would actually convert — that selection happens later during
the migration. What the queries do settle is which row is the *current* version of a
versioned record, because that has to be right before anything downstream can use them.

## The shape of every module

The files in each `sql/` folder fall into the same few groups. Once you have read one
module, the others follow the same layout.

| File pattern | What it is |
|---|---|
| `huron_<module>.sql` | The root dataset — one row per current record, with lookups folded in and the BU extension joined |
| `huron_<module>_<child>.sql` | One dataset per one-to-many child collection (people, amounts, terms, and so on) |
| `huron_<module>_custom.sql` | BU custom fields for the module, presented by name rather than as raw EAV rows |
| `huron_<module>_latest_version_validation.sql` | The counts and exceptions that prove the version-selection rule. Negotiation has `population_validation.sql` instead, because it is not versioned |
| `sql/json/` | A nested JSON proof of concept that returns one complete business object as a single document, in case that shape is useful |

Two rules hold across all of them. One-to-many collections are kept in their own datasets
rather than joined onto the root — one award with 5 people, 12 terms and 40 custom fields
would otherwise come back as 2,400 duplicate award rows. Many-to-one lookups go the other
way and are folded into the root as code plus description, because a lookup cannot multiply
rows. So the root query is wide but never multiplies, and each child query is one clean
collection.

## Lineage keys — how the datasets reassemble

Every child dataset carries the root's lineage keys alongside its own primary key, so the
whole graph can be put back together against the right version of the record. For Award
that means `AWARD_ID`, `AWARD_NUMBER` and `SEQUENCE_NUMBER` travel on every child row; the
other modules carry their own equivalents. Children are always fetched through the selected
root's id — we never recompute `MAX(SEQUENCE_NUMBER)` on a child table, because that would
mix rows from different versions of the same record.

## How the version rule is built into each query

For the three versioned objects, every query starts with the same CTE that picks the
current row. Here is the Award one — it prefers the row KC marks `ACTIVE`, then the highest
sequence, then the highest `AWARD_ID`, so it is deterministic and returns exactly one row
per award number:

```sql
WITH huron_award_version AS (
    SELECT award_id, award_number, sequence_number, selection_rule
    FROM (
        SELECT a.award_id, a.award_number, a.sequence_number,
               CASE WHEN a.award_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY a.award_number
                   ORDER BY CASE WHEN a.award_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            a.sequence_number DESC,
                            a.award_id        DESC
               ) AS rn
        FROM   kcoeus.award a
    )
    WHERE rn = 1
)
```

The root and every child then `JOIN huron_award_version` so they all resolve to the same
selected version. If you want all historical sequences instead of the current one, remove
that join — the comment at the foot of each query says so. The root also exposes a
`SELECTION_RULE` column so you can see which branch chose each row; nothing is silently
deduplicated. Proposal and Subaward use the same idea with their own ordering (Subaward
adds `UPDATE_TIMESTAMP` as a tie-breaker). Negotiation has no such CTE because there is only
one row per negotiation.

## Lookups are datatype-aware

The root joins decode coded columns against their reference tables, and several of those
joins need a datatype conversion that is easy to miss. On Award, for example,
`STATUS_CODE` and `ACTIVITY_TYPE_CODE` are numbers that decode against `VARCHAR2` columns,
so the join uses `TO_CHAR`; `TRANSACTION_TYPE_CODE` is the reverse and uses `TO_NUMBER`
(safe, because none of its values are non-numeric). Each root query carries a comment
listing the conversions it makes and any codes that don't resolve. We left the unmatched
codes alone rather than inventing a fix — on Award that is `transaction_type_code` on 15
rows, `sponsor_code` on 3, and `prime_sponsor_code` on 6.

## Custom-field datasets

The `*_custom.sql` files turn the EAV custom data into something mapping-friendly. The raw
`*_CUSTOM_DATA` tables store a `CUSTOM_ATTRIBUTE_ID` and a generic `VALUE`, so each custom
query joins `CUSTOM_ATTRIBUTE` to bring back the field's name, label, group and datatype
next to the value. Two details in these files are deliberate and worth knowing:

- The join to `CUSTOM_ATTRIBUTE_DOCUMENT` is filtered to the module's document type (for
  example `'AWRD'`), because an attribute can be attached to several document types and an
  unfiltered join would multiply rows. Where `APPLIES_TO_DOCUMENT_TYPE` comes back NULL, the
  attribute has values but is not configured for that module — we surface it rather than
  drop it.
- `CUSTOM_ATTRIBUTE` is `LEFT JOIN`ed on purpose. On Award, two rows reference attribute ids
  that no longer exist in `CUSTOM_ATTRIBUTE`; an inner join would silently discard them, so
  we keep them visible with a NULL definition as the anomaly they are.

## The datasets, module by module

The tables below list what each module exposes. The child datasets all carry the root
lineage keys described above.

### Award — `modules/award/sql/`

Root `huron_award.sql`, its validation query, and 21 child datasets.

| Dataset | Covers |
|---|---|
| `huron_award` | Root: core award fields, folded-in lookups, BU `AWARD_EXTENSION` fields |
| `huron_award_person` | Investigators / key personnel |
| `huron_award_person_unit` | Units under each person |
| `huron_award_person_credit_split` | Person-level credit splits |
| `huron_award_person_unit_credit_split` | Unit-level credit splits |
| `huron_award_amount` | Award amount / time-and-money history |
| `huron_award_fanda_distribution` | Direct F&A distribution |
| `huron_award_sponsor_term` | Sponsor terms |
| `huron_award_report_term` | Report terms |
| `huron_award_special_review` | Special reviews |
| `huron_award_special_review_exemption` | Special-review exemptions |
| `huron_award_cost_share` | Cost sharing |
| `huron_award_idc_rate` | Indirect-cost (F&A) rates |
| `huron_award_cfda` | CFDA numbers |
| `huron_award_closeout` | Closeout items |
| `huron_award_comment` | Comments |
| `huron_award_attachment` | Attachments (metadata; content is not exported) |
| `huron_award_unit_contact` | Unit contacts |
| `huron_award_hierarchy` | Award hierarchy — keys on `AWARD_NUMBER`, not `AWARD_ID` |
| `huron_award_funding_proposal` | Link to the funding Institutional Proposal |
| `huron_award_approved_subaward` | Approved subawards |
| `huron_award_custom` | BU custom fields (46 `AWRD` attributes) |
| `huron_award_latest_version_validation` | Proof of the version-selection rule |

The personnel chain is the part most likely to be joined wrongly. `AWARD_PERSON_UNITS` and
the credit splits key on the *person* row (`AWARD_PERSON_ID`), not on the award, and the
Java property names drift from the column names. `AWARD_HIERARCHY` keys on `AWARD_NUMBER`
because the hierarchy describes the award rather than a version. Both are set out in
[AWARD_GRAPH.md](../modules/award/AWARD_GRAPH.md).

### Institutional Proposal — `modules/proposal/sql/`

Root `huron_proposal.sql`, its validation query, and the child datasets below.

| Dataset | Covers |
|---|---|
| `huron_proposal` | Root: core proposal fields, folded-in lookups, BU `PROPOSAL_EXTENSION` fields |
| `huron_proposal_person` | Proposal persons |
| `huron_proposal_person_unit` | Units under each person |
| `huron_proposal_person_credit_split` | Person-level credit splits |
| `huron_proposal_person_unit_credit_split` | Unit-level credit splits |
| `huron_proposal_special_review` | Special reviews |
| `huron_proposal_special_review_exemption` | Special-review exemptions |
| `huron_proposal_cost_share` | Cost sharing |
| `huron_proposal_cfda` | CFDA numbers |
| `huron_proposal_comment` | Comments |
| `huron_proposal_notepad` | Notepad entries |
| `huron_proposal_attachment` | Attachments (metadata) |
| `huron_proposal_unit_contact` | Unit contacts |
| `huron_proposal_funding_award` | Link to funding awards |
| `huron_proposal_ip_review` | Intellectual-property review — its own versioned object, reached through a join |
| `huron_proposal_log` | Intake record, a separate object sharing `PROPOSAL_NUMBER` |
| `huron_proposal_custom` | BU custom fields (45 `INPR` attributes) |
| `huron_proposal_latest_version_validation` | Proof of the version-selection rule |

Two of these are not ordinary children. `PROPOSAL_LOG` is a separate intake object that
shares the proposal number, and it must not be joined on `INST_PROPOSAL_NUMBER` — we tested
all 30,646 populated values and none matches a real proposal number. `IP_REVIEW` is its own
versioned object reached through `PROPOSAL_IP_REVIEW_JOIN`. Both are explained in
[PROPOSAL_GRAPH.md](../modules/proposal/PROPOSAL_GRAPH.md).

### Subaward — `modules/subaward/sql/`

Root `huron_subaward.sql`, its validation query, and the child datasets below.

| Dataset | Covers |
|---|---|
| `huron_subaward` | Root: core subaward fields; BU `SUBAWARD_EXTENSION` (`DATE_RECEIVED`) folded in |
| `huron_subaward_funding_source` | Funding awards — points at a specific award *version* |
| `huron_subaward_amount` | Amount / modification history |
| `huron_subaward_amount_released` | Amount released / invoicing — barely used at BU (returns nothing today) |
| `huron_subaward_contact` | Contacts — uses `REQUISITIONER_ID`, not `ROLODEX_ID` |
| `huron_subaward_ffata` | FFATA reporting |
| `huron_subaward_report` | Reports (empty at BU) |
| `huron_subaward_template_info` | Agreement terms — 48 business columns, 1:1 in practice |
| `huron_subaward_template_attachment` | Template attachments (empty at BU) |
| `huron_subaward_closeout` | Closeout (empty at BU) |
| `huron_subaward_attachment` | Attachments (metadata) |
| `huron_subaward_custom` | BU custom fields (15 `SAWD` attributes) |
| `huron_subaward_latest_version_validation` | Proof of the version-selection rule |

The funding-source dataset is the join to Award, and it carries
`FUNDING_AWARD_VERSION_IS_CURRENT` and `CURRENT_AWARD_ID` because 74% of the recorded links
point at an award version that has since been superseded. Join to the Award root on
`funding_award_number`. See [SUBAWARD_GRAPH.md](../modules/subaward/SUBAWARD_GRAPH.md).

### Negotiation — `modules/negotiation/sql/`

Negotiation is not versioned, so there is no version CTE and no
`latest_version_validation.sql`. It keeps a population-validation query instead.

| Dataset | Covers |
|---|---|
| `huron_negotiation` | Root: negotiation fields, `ASSOCIATED_DOCUMENT_ID_MEANS`, and the 1:1 `NEGOTIATION_UNASSOC_DETAIL` folded in |
| `huron_negotiation_activity` | The activity log — the real negotiation history |
| `huron_negotiation_activity_attachment` | Attachments, which hang off the activity, not the negotiation |
| `huron_negotiation_custom` | BU custom fields (8 `NGT` attributes) |
| `huron_negotiation_population_validation` | The check that confirms it is not versioned |

The root folds in `NEGOTIATION_UNASSOC_DETAIL` because it is 1:1 and holds the real content
for the 78% of negotiations that are not attached to anything. `NEGOTIATION_CUSTOM_DATA`
carries a `NEGOTIATION_NUMBER` column that is NULL on every row — join on `NEGOTIATION_ID`.
See [NEGOTIATION_GRAPH.md](../modules/negotiation/NEGOTIATION_GRAPH.md).

## Regenerating and re-running

The queries are hand-written and version-controlled; they are not generated. The graph and
mapping CSVs that describe each module *are* generated — see the
[onboarding guide](ONBOARDING.md) for how to rebuild them and how to run any query through
the read-only runner.
