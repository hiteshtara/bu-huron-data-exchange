# Draft reply to Phil — Grants data dump (DRAFT, review before sending)

> Internal note: this is a draft for BU to review/edit and send. Do not send until
> data-governance sign-off for external transfer is confirmed. See
> reference/GRANTS_DATA_DUMP_FOR_HURON.md for the full package plan.

---

Phil,

Thanks — yes, we're positioned to send you Grants data for the AI mapping head start, and
we'd like to take advantage of it to accelerate that portion of the project.

Our Grants source is Kuali Coeus (KC) on Oracle. Since you noted that fields matter more than
rows, we're planning to send:

1. **A complete data dictionary** for the in-scope KC Grants tables — every table, column,
   datatype, nullability, and column comment. This gives your tooling clearly-defined headers
   for the full field set.
2. **Representative row samples** (~1,000 rows/table) so the tooling sees real values and formats.
3. **Reference/lookup tables in full** (sponsors, units, statuses, types, rate types) so coded
   values are decodable, plus our **custom-attribute definitions** — the BU-specific extended
   fields that will need explicit mapping decisions.

Scope covers Proposal Development, Institutional Proposals, Awards, Subawards, and Negotiations,
plus the common/reference data those modules depend on.

Two things on our side before delivery:

- **Format:** we'll send CSV files plus the data dictionary. If your tooling would rather ingest
  a SQL schema/table dump, let us know and we'll provide that instead.
- **PII:** person records carry names/emails and, in places, more sensitive identifiers. For the
  mapping exercise we'll send the person/contact **column structure with a small, masked sample**
  rather than the full population. If you need un-masked values for any specific field, tell us
  which and we'll route it through our data-governance review.

Can you confirm (a) your preferred **row-sample size**, (b) **file vs. SQL table**, and (c) the
**secure channel** you'd like us to use for delivery? Once we have those we can turn this around
quickly.

Best,
[Name]
