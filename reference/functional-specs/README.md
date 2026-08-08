# Historical BU functional specifications

Background documents that explain why BU's KC data is shaped the way it is. They are
supporting evidence for business meaning. They are **not** authoritative for the Huron
migration — current production data and current KC source are.

## What is here

### KCRM-SAP Grants Interface (IFI_GM001)

**Functional Design Specification: Interface — KCRM-SAP Grants Interface, IFI_GM001,
version 4.1, revised April 26, 2012.** Boston University. 69 pages.

Specifies the real-time interface that pushed KC ("KCRM") award data into SAP Grants
Management. Its value to us is the Award hierarchy: it is the only place we have found
where BU wrote down what the parent/child structure was *for*.

The sections that matter, and what we took from them, are summarised in
[AWARD_GRAPH.md](../../modules/award/AWARD_GRAPH.md) under "Historical BU business
context". In short:

| Section | Pages | Subject |
|---|---|---|
| 1.3.1 | 7–8 | Award Actions, including adding a child to another child |
| 1.5.1–1.5.2 | 9–10 | Interface launches from the Parent Award; the `00001` node is always selected |
| 1.5.6 | 13 | A Sponsored Program can only come from a child with no children of its own |
| 1.6 | 14–16 | Sponsored Program number generation into `Award.Account_Number` |
| 1.7.1 | 16–18 | `Grant_Main` maps 1:1 from the Parent Award |
| 1.7.4 | 21–22 | Each Child Award becomes a Sponsored Program |
| 1.7.8 | 27 | Sponsored Program Group for awards with grandchildren |
| 1.9.5 | 63–65 | How SAP built those groups |
| 1.12 | 68–69 | Validation rules by hierarchy position |

Mapping tables M1–M10 and R (pp. 28–34) hold the code translations of the day. They
describe SAP targets and are of historical interest only.

## Why the file itself is not committed

The PDF is an internal BU functional specification. It names individual staff and
includes their email addresses, and it documents internal financial system
configuration — account number ranges, SAP table names, interface logic.

None of that is needed to use this repository, so the file is gitignored
(`reference/functional-specs/*.pdf`) and the working copy stays local. **Whether it can
be committed is a BU decision, not ours.** If BU confirms it is fine to keep in this
repository, remove that line from `.gitignore` and commit it here.

Nothing in the tracked documentation reproduces the personal information in it. We cite
the document by title, version, section and page only.
