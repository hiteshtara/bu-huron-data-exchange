# Draft reply to Phil — Grants data dump (DRAFT, review before sending)

> Internal note: this is a draft for BU to review/edit and send. Do not send until
> data-governance sign-off for external transfer is confirmed. See
> discovery/GRANTS_DATA_DUMP_FOR_HURON.md for the full package plan and
> discovery/00_PACKAGE_README.txt for what actually ships.

---

Phil,

Thanks — yes, we'd like to take you up on the AI mapping head start for Grants. We've now
run discovery against our Kuali Coeus production schema and have a package close to ready.

Our Grants source is Kuali Coeus (KC) on Oracle. Since you noted that fields matter more than
rows, here's what we're planning to send:

1. **A field dictionary that goes well beyond the schema.** One thing worth flagging early:
   KC stores **no column comments in Oracle at all**, so a plain database dump would give your
   tooling column names and datatypes and nothing else. The business meaning lives in the
   Kuali application's DataDictionary, so we've extracted it and joined it to the schema. For
   each field you'll get the Oracle table and column, the Java object and property, the
   **actual front-end label BU users see**, the lookup/reference object that decodes coded
   values, and a mapping priority. That's 6,194 fields, 3,280 with a confirmed UI label.

   This matters more than it sounds. `AWARD.AWARD_NUMBER` is labelled **"Award ID"** on screen,
   `AWARD.SPONSOR_CODE` is **"Sponsor ID"**, and `PROPOSAL.TITLE` is **"Project Title"** — none
   of which you'd guess from the column name. Where we could not find a label in the source we
   left it blank rather than inventing one.

2. **A complete data dictionary** for the 359 in-scope Grants tables — 4,074 columns with
   datatype, nullability, default, and the UI label where known.

3. **Representative row samples** (~1,000 rows/table, spread across the table rather than the
   first N rows) so your tooling sees real values and formats. All columns and all lineage keys
   are retained; only the row count is reduced.

4. **Reference/lookup tables in full** — 164 tables including sponsors, organizations, units,
   statuses, types and rate types — so every coded value in the transactional files decodes.

5. **Our BU-specific custom fields, already resolved.** BU has 107 configured custom attributes
   (46 Award, 45 Institutional Proposal, 15 Subaward, 8 Negotiation). KC stores these EAV-style,
   so the raw tables would show you `CUSTOM_ATTRIBUTE_ID = 1234` and a generic `VALUE` column —
   effectively meaningless outside KC. We're sending both a normalized extract with the
   attribute name, label and group joined on, **and** a pivoted version with one named column
   per custom field, plus a header dictionary for it. These are BU-specific fields that will
   need explicit mapping decisions, so we'd rather you see them as named fields.

Scope covers Awards, Institutional Proposals, Subawards, Negotiations and Proposal
Development, plus the common/reference data those modules depend on. We've excluded 542
tables — backups, dated snapshots, temp/working tables, and the IRB/IACUC and platform
workflow tables — each with a documented reason.

Two things worth knowing about our data:

- **Proposal Development looks unused at BU.** `EPS_PROPOSAL` has 1 row against 130,121
  Institutional Proposals. We're confirming internally, but you probably shouldn't size a
  Proposal Development conversion.
- Budgets in our instance attach to **Awards**, not proposals.

And two things on our side before delivery:

- **PII:** person and contact records carry names, emails and in places more sensitive
  identifiers. For the mapping exercise we're sending the column structure with a small sample
  and the personal values redacted — the fields and datatypes are visible, the people are not.
  If you need un-masked values for a specific field, tell us which and we'll route it through
  our data-governance review.
- **Format:** CSV files plus the dictionaries. If your tooling would rather ingest a SQL
  schema/table dump, say so and we'll provide that instead.

Could you confirm (a) your preferred **row-sample size**, (b) **file vs. SQL table**, and
(c) the **secure channel** you'd like us to use for delivery? Once we have those we can turn
this around quickly.

Best,
[Name]
