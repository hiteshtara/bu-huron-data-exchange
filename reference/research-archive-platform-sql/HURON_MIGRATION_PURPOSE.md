# How the Research Archive SQL can help the Huron migration

## Why we kept this SQL

The Research Archive work solved many of the same source-data questions that the Huron migration must solve: where a business object lives in Kuali, which identifier establishes its grain, how child tables connect to it, where lookup descriptions come from, and how to prove an extract is complete.

We copied that work here so BU and Huron can reuse the evidence instead of rediscovering it. The files are particularly useful when a table name is misleading, a child does not carry the expected parent key, or a Kuali relationship exists only through an intermediate table.

These files are supporting material. The curated SQL under `modules/<object>/sql/` remains this repository's proposed source interface for Huron. Nothing in this reference directory is automatically approved for migration use.

## Where this helps in the migration

```text
Kuali source discovery
        ↓
Confirm table grain and relationships
        ↓
Build the BU-to-Huron field mapping
        ↓
Adapt the approved extraction SQL
        ↓
Create migration files or another agreed delivery format
        ↓
Reconcile source, transformed, delivered, and loaded counts
        ↓
Trace sample Huron records back to Kuali identifiers
```

| Migration activity | How this reference helps | Expected output |
|---|---|---|
| Source discovery | Shows verified Kuali tables, columns, joins, and metadata queries | Confirmed source objects and owners |
| Grain decisions | Preserves Award, Proposal, Subaward, Negotiation, and child-record identifiers | One documented row grain per dataset |
| Field mapping | Exposes raw IDs alongside codes and descriptions | Source-to-Huron mapping rows |
| Transformation design | Records joins, version rules, denormalized lookups, and known exceptions | Reviewed transformation rules |
| Attachment planning | Separates attachment references, physical files, metadata, and BLOB location | Attachment manifest and transfer plan |
| Validation | Includes duplicate-key, null-key, orphan, lookup, and row-count checks | Pre-load validation results |
| Reconciliation | Provides PostgreSQL examples of business-grain and child-count verification | Source-to-target count report |
| Troubleshooting | Preserves stable source identifiers for record-level tracing | One-record end-to-end trace |

## What Huron can learn from each module

### Award

Award is not one flat record. `AWARD_NUMBER` identifies an Award/account across versions, while `AWARD_ID` identifies a physical version row. Award hierarchy adds another level by connecting root and child Award numbers.

The reference queries can help Huron review:

- whether the target grain is an Award family, an Award/account, a version, or more than one of these;
- how people, units, credit splits, terms, contacts, comments, compliance records, budgets, and Time and Money records relate to an Award version;
- which child tables carry `AWARD_ID` directly and which require a join through an intermediate parent;
- which records are version-specific and which are keyed only by Award number;
- how physical attachment files are deduplicated by `FILE_ID` even when several Award attachment references point to the same file.

These findings support the Award grain decision already recorded in `reference/HURON_REVIEW_ITEMS.md`. They do not decide which grain Huron should load.

### Institutional Proposal

Proposal queries preserve proposal number, proposal ID, sequence number, document number, people, roles, units, contacts, comments, attachments, and custom values.

They can help distinguish:

- a Proposal business identifier from a physical version row;
- Proposal people from their unit assignments;
- attachment metadata from binary content;
- configured custom attributes from values that appear outside their configured document type.

This is useful when Huron maps one Proposal record into several related target collections and BU needs to retain traceability to the original Kuali version.

### Negotiation

Negotiation is not versioned like Award, Proposal, or Subaward. One `NEGOTIATION_ID` represents one Negotiation business record.

The copied SQL shows that:

- activities, custom data, notifications, and unassociated details are separate children;
- notification ownership uses `OWNING_DOCUMENT_ID_FK`, not a column named `NEGOTIATION_ID`;
- attachment ownership must be resolved from `NEGOTIATION_ATTACHMENT` through `NEGOTIATION_ACTIVITY`;
- status, agreement type, association type, activity type, and location descriptions come from lookup joins;
- unassociated details are a valid Kuali structure for Negotiations that do not point to an Award, Proposal, or Subaward.

These joins can help Huron avoid losing the majority population of unassociated Negotiations or attaching notifications and files to the wrong parent.

### Subaward

`SUBAWARD_CODE` identifies the version family, while `SUBAWARD_ID` identifies the physical source row. The reference set separates funding sources, amounts, contacts, custom values, reports, closeout, notes, notifications, templates, and attachments.

The most important migration issue is the funding relationship. Kuali can retain the specific historical Award version that funded a Subaward. Huron and BU still need to decide whether the target keeps that historical link, links to the current Award, or carries both.

The validation package also provides a reusable pattern for checking source primary keys, nulls, orphans, lookups, constraints, indexes, and row counts before producing migration files.

### Reference data

The reference queries cover Units, Unit Administrator Types, Unit Administrators, Rolodex contacts, people, Comment Types, Custom Attributes, and Custom Attribute document configuration.

These queries help BU preserve both the stored code and its business description. They also show where a lookup is unverified. When the source does not prove a meaning, the migration should preserve the raw value and leave the interpretation for BU/Huron review rather than inventing a description.

### Protocol

The Protocol queries are included as additional Kuali evidence. They preserve version, person, and unit identifiers and document a non-obvious parent-resolution path. Protocol is outside the four-module status table in the root README, so its migration scope and target mapping require separate confirmation.

## Attachments need their own migration plan

An attachment reference and a physical file are not always the same thing. Several business records may reference one `FILE_ID`, and binary content may live inline in `ATTACHMENT_FILE.FILE_DATA` or through the external `FILE_DATA.DATA` relationship.

For Huron planning, BU can use the attachment SQL to produce separate counts for:

1. business attachment references;
2. distinct physical file IDs;
3. files with inline content;
4. files with external content;
5. metadata rows with no available content;
6. files selected, transferred, accepted, rejected, and loaded by Huron.

That separation prevents duplicate transfers and makes missing content visible instead of silently treating metadata as proof that a file was migrated.

## How BU should turn a reference query into migration SQL

1. Start with the curated query under `modules/<object>/sql/`.
2. Use this reference collection to verify joins, source columns, historical grain, and edge cases.
3. Confirm the real Oracle owner, synonyms, grants, and current production shape.
4. Write down the source grain and primary identifier before adding joins.
5. Map every selected column to a Huron object and field, including null and default behavior.
6. Remove archive-only columns or logic that Huron does not need.
7. Add only the population filters jointly approved for migration.
8. Run structural, count, field, business-rule, and sample-record validation.
9. Reconcile the delivered output with Huron's loaded and rejected counts.
10. Keep the original Kuali identifiers in the migration output or a crosswalk so every Huron record can be traced back.

## Minimum reconciliation package

For each delivered dataset, we should be able to show:

```text
Oracle source candidates
- explicitly excluded records
= expected migration records

expected migration records
= generated output records

generated output records
= Huron loaded records + Huron rejected records
```

The supporting report should include:

- the query version or commit;
- extraction timestamp and source environment;
- source and target grain;
- source count and exclusion counts by rule;
- distinct business-key and physical-row counts where they differ;
- duplicate, null-key, and orphan counts;
- generated, delivered, loaded, and rejected counts;
- representative record traces using preserved Kuali IDs;
- unresolved BU/Huron decisions.

## What still requires BU/Huron agreement

The SQL proves source structure; it does not settle target decisions. At minimum, the teams still need to agree on:

- Huron object and field mappings;
- current-only versus historical conversion rules;
- Award family and Award/account grain;
- the Subaward-to-Award funding-version rule;
- the treatment of unassociated Negotiations;
- attachment scope, supported file types, and transfer protocol;
- handling of restricted notes, messages, and files;
- code translations and default values;
- physical delivery, mock-conversion, retry, and cutover procedures;
- acceptance thresholds and reconciliation sign-off.

The current joint questions are maintained in [`../HURON_REVIEW_ITEMS.md`](../HURON_REVIEW_ITEMS.md).

## Boundaries

- These are read-only reference copies, not a Huron load package.
- The original Research Archive Platform repository remains the source of truth for these copies.
- The current BU Huron module SQL remains the proposed source interface.
- PostgreSQL reference queries use Research Archive table names and require adaptation.
- SQLPlus settings may need removal in other Oracle clients.
- No credentials, connection strings, or extracted BU rows belong in this directory.
- A technically correct query is not approved for migration until BU validates it and BU/Huron resolve the applicable mapping decisions.

See [`README.md`](README.md) for the complete file catalog and [`SQL_INVENTORY.csv`](SQL_INVENTORY.csv) for the source path, database, purpose, classification, and execution status of every inventoried SQL file.
