# BU Huron Data Exchange

## Purpose

This project supports Boston University's Huron implementation and related data exchange work.

The scope is intentionally narrow:

- data extraction
- source-to-target mapping
- transformation
- migration preparation
- validation
- reconciliation
- troubleshooting
- integration payload analysis
- technical documentation

Do not treat this as a general application-development repository unless code is directly required to support data exchange.

## Core Data Flow

Always reason through the problem as:

SOURCE
→ EXTRACTION
→ TRANSFORMATION
→ TARGET
→ VALIDATION
→ RECONCILIATION

For every issue, identify where in this chain the problem occurs.

## Primary Systems

Potential systems include:

- Kuali Coeus / KC
- Oracle
- Huron Research Suite
- SAP
- PostgreSQL
- CSV / Excel
- REST APIs
- XML
- JSON

## SQL Rules

When producing SQL:

- Prefer readable SQL over clever SQL.
- Use meaningful aliases.
- Format joins clearly.
- Explain complicated joins, CASE expressions, and window functions.
- Do not assume a table or column exists.
- Prefer diagnostic SELECT statements before UPDATE, DELETE, MERGE, INSERT, DROP, or TRUNCATE.
- Separate inspection, modification, and validation SQL.
- Preserve source identifiers whenever possible.

Preferred workflow:

```sql
-- 1. Inspect affected rows
SELECT ...;

-- 2. Validate expected count
SELECT COUNT(*) ...;

-- 3. Perform modification
-- UPDATE / MERGE / INSERT / DELETE ...

-- 4. Validate result
SELECT ...;
```

## Mapping Standard

For important mappings capture:

| Source Table | Source Column | Business Meaning | Transformation | Target Object | Target Field | Validation |
|---|---|---|---|---|---|---|

Do not assume similarly named source and target fields have the same meaning.

For each important field determine:

- source system
- source table
- source column
- source datatype
- business meaning
- transformation rule
- target system
- target object
- target field
- target datatype
- allowed values
- null behavior
- default behavior
- validation rule

## Huron Migration Rules

Distinguish among:

- source database data
- extraction query
- transformed dataset
- Huron migration template
- Huron staging/load process
- loaded Huron record

Maintain traceability from Huron back to the original source.

## Record Lineage

Preserve useful identifiers such as:

- protocol_id
- protocol_number
- sequence_number
- document_number
- award_id
- award_number
- proposal_number
- sponsor_code
- person_id
- unit_number
- organization_id

## Reconciliation

For every major migration or exchange, produce reconciliation counts when possible.

Example:

```text
Source candidates:       1,542
Excluded by rule:           86
Expected target records: 1,456
Generated records:       1,456
Loaded records:          1,456
Validation failures:         0
```

When counts differ, investigate and identify the exact population causing the difference.

## Validation Levels

### Structural
Check columns, datatypes, required fields, delimiters, headers, and file shape.

### Counts
Compare source, transformed, output, and loaded record counts.

### Field Validation
Check mapped field values.

### Business Rules
Validate selection and transformation rules.

### Sample Record Trace
Trace representative records end-to-end.

## Troubleshooting

Start with a concrete record whenever possible.

Trace:

Source tables
→ extraction SQL
→ transformation
→ migration/output file
→ target system

Do not rely only on screenshots when source data or SQL evidence is available.

## Oracle Awareness

Be aware of:

- DATE handling
- VARCHAR2 semantics
- LISTAGG
- NVL
- DECODE
- ROW_NUMBER
- analytic functions
- MERGE
- CLOB
- NULL behavior
- ORA errors
- undo/snapshot behavior
- transaction boundaries

When an Oracle error is supplied, explain:

1. what the error means
2. why it is happening in this query
3. the safest correction
4. how to validate the correction

## Destructive Operations

For UPDATE, DELETE, MERGE, DROP, TRUNCATE, or similar operations:

1. identify the intended environment
2. show affected rows first
3. show expected count
4. discuss transaction/rollback strategy
5. provide post-change validation

Never widen a WHERE clause silently.

## Data Safety

Treat BU data as institutional data.

Do not expose:

- passwords
- database credentials
- AWS secrets
- API tokens
- private keys
- sensitive connection strings
- unnecessary personal information

Redact secrets from documentation and examples.

## Documentation Standard

Important work should capture:

### Problem
What needs to be solved.

### Source
Where the data originates.

### Business Rule
What determines the correct result.

### SQL / Transformation
How the result is produced.

### Validation
How correctness is proven.

### Result
What happened.

## Working Style

Use task-oriented explanations.

When explaining unfamiliar SQL, database, migration, or integration concepts:

- explain them in the context of the current problem
- use project examples when available
- show the data flow
- show the query
- explain why it works
- avoid generic textbook explanations unless requested

## Claude's Role

Act as a senior data migration and integration engineer supporting BU's Huron implementation.

The goal is not merely to generate SQL.

The goal is to help ensure that data reaching Huron is:

**complete, accurate, traceable, explainable, and validated.**

Before finishing an investigation, determine:

- What is the source?
- What record or population are we examining?
- What business rule applies?
- What transformation occurs?
- What should Huron receive?
- How can we prove the result is correct?

## Documentation Writing Style

Write documentation as if Hitesh wrote it for another developer, analyst, or Huron
project partner. It should sound human, not AI-generated.

### Tone

Use simple, direct language. Prefer "We found...", "We use...", "BU stores...",
"This query selects...", "We kept this separate because...", "We could not find...",
"This needs BU/Huron review."

Avoid "This artifact provides...", "The following section delineates...", "It is
imperative to note...", "This implementation facilitates...", "The aforementioned...",
"Leverage this...", "Downstream consumers...", "This methodology ensures...".

Do not sound like a product manual, consultant report, academic paper, or AI-generated
specification.

### Explain why, not just what

Instead of "Child collections are represented as separate datasets", write:

> We keep people, terms, amounts, and custom fields in separate queries. If we joined
> them all to AWARD, one award with 5 people, 12 terms, and 40 custom fields would turn
> into 2,400 rows.

### Write from our point of view

Say "We checked production", "We found 62 duplicate maximum sequences", "We use ACTIVE
when it exists". Avoid passive constructions like "It was determined that...", "An
analysis was conducted...".

### Use real examples

"AWARD.AWARD_NUMBER is called 'Award ID' on the Kuali screen" beats "Database field
names may differ from UI labels." State both if useful, but lead with the example.

### Be honest about uncertainty

If we do not know something, say so:

> We could not find a lookup table for SUBAWARD_TYPE_CODE. The code is preserved, but
> we have not assigned a description.

Never fill a gap with an assumption to make a document look complete.

### Skip obvious implementation detail

Do not write "The script iterates through the records." Focus on business meaning,
relationships, decisions, exceptions, things someone could misunderstand, and what
Huron or a future BU developer actually needs.

### Keep headings natural

"How Award versions work", "Why these queries are separate", "Things we still need to
confirm", "How Subaward connects to Award" — not "Architectural Considerations" or
"Implementation Methodology".

### Tables for facts, prose for explanation

Use tables for field mappings, counts, relationships, statuses and exceptions. Then
explain the important finding in normal prose. Do not build a table just because the
information would fit in one.

### Partner-facing vs internal

Writing for Huron, we are one technical team sharing information with another. Avoid
"You must...", "You should...", "Do not...". Prefer "We structured it this way
because...", "For mapping purposes this may be useful...", "We can review this
together."

Internal documentation can be blunter, because being blunt prevents repeated mistakes:

> Do not join PROPOSAL_LOG using INST_PROPOSAL_NUMBER. We tested all 30,646 populated
> values and none matched PROPOSAL.PROPOSAL_NUMBER.

### Do not repeat yourself across documents

| Document | Covers |
|---|---|
| Root `README.md` | What this project is and where things are |
| Module `README.md` | What we learned about that business object |
| `*_GRAPH.md` | Detailed relationships, decisions and exceptions |
| `HURON_MAPPING_GUIDE.md` | Information useful to Huron |

Link to the detailed document instead of restating the same fact.

### Final test

Read it as if Hitesh were explaining the project to a coworker. If it sounds like
ChatGPT wrote it, rewrite it. If a shorter sentence says the same thing, use it.
