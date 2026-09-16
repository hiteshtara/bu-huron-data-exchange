# Live demo pack

Six read-only queries for showing Huron what is actually in KC, plus what to say
while each one runs. Built for the BU/Huron review session.

**Run all six yourself before the meeting.** They are written against the same
tables and the same version-selection rules as the module SQL, but they have not
been executed against production — do not demo a query you have not seen return.
Query 4 in particular needs an award number you have checked.

## Before the meeting

Confirm the connection, and confirm it comes back read-only:

```bash
.venv/bin/python scripts/kc_prod_readonly_query.py --test
```

You want `Database: KUALI` and `Mode: READ ONLY`. If the password isn't in the
Keychain the runner prints the exact `security` command to fix it. Full setup is in
[ONBOARDING.md](../ONBOARDING.md).

Then run each demo query once and note the row counts, so nothing surprises you on
the screen:

```bash
for q in docs/demo/*.sql; do
  echo "== $q"
  .venv/bin/python scripts/kc_prod_readonly_query.py --file "$q" --limit 25
done
```

## Running one during the meeting

```bash
.venv/bin/python scripts/kc_prod_readonly_query.py --file docs/demo/01_population_reconciliation.sql
```

Add `--limit 20` to cap what lands on screen, `--output /tmp/x.csv` to save it.

## The six queries

| # | Query | What it shows | The line to say |
|---|---|---|---|
| 1 | [Population reconciliation](01_population_reconciliation.sql) | All four objects, physical rows against business records | "This is the whole Grants conversion in one result. The gap between those two columns is the versioning problem." |
| 2 | [Why MAX(SEQUENCE) is wrong](02_why_max_sequence_is_wrong.sql) | The award numbers with two rows at the same highest sequence | "Take the latest sequence and you get more rows than there are awards. Each of these is a coin flip between an ACTIVE row and an ARCHIVED one." |
| 3 | [Award families](03_award_families.sql) | Family-size distribution behind the 15,729 | "43,202 awards, but 15,729 funded projects. Which of those two numbers HRS expects is decision D-17." |
| 4 | [One award end to end](04_one_award_end_to_end.sql) | A single award with every child collection counted | "That last column is what one flat join would have returned for this one award. That is why the child collections ship as separate datasets." |
| 5 | [Subaward to Award funding](05_subaward_to_award_funding.sql) | How many funding links point at a superseded award version | "Three quarters of them point at an award version that is no longer current. We preserved what KC recorded rather than repointing it. That is D-01." |
| 6 | [BU custom fields](06_bu_custom_fields.sql) | The EAV model resolved into BU's real field labels | "Read the raw table and it is numbers against numbers. This is what the schema alone cannot tell you, and it is most of the work in this repository." |

Good order is 1 → 2 → 3 → 4 → 5 → 6: scale, then why the version rule exists, then
grain, then dataset shape, then the cross-module link, then the field-level work. If
time runs short, 1, 4 and 6 carry the demo on their own.

## Talking about connectivity

This will come up, and it is worth being precise, because the honest answer is more
useful than an improvised one.

**What exists today.** BU developers query KC production through
`scripts/kc_prod_readonly_query.py`. That runner accepts only `SELECT` and `WITH`,
opens the transaction read-only, and reads its password from the local Keychain.

**What that is not.** It is not a connection BU can hand to Huron. Every one of those
controls is a property of the runner, not of the account — a different client using
the same connection details would inherit none of them. That is the distinction to
make out loud, because "BU already connects to production every day" sounds like it
answers the access question and it does not.

So the demo is BU running queries on screen. It is not a walkthrough of how Huron
would connect, because **no Huron access path has been provisioned and the delivery
method is still an open joint decision (D-18).** If Huron asks how they get to the
data, the answer is the four options in
[HURON_CONNECTIVITY.md](../HURON_CONNECTIVITY.md) and the five questions BU needs
answered — not credentials, a tunnel, or a host name.

If the room pushes toward direct database access (Option B), what BU would need to
design is a dedicated migration identity with `SELECT` only, scoped to approved
curated views, with BU-approved authentication and network controls, and a security
approval path that should start early. None of that exists yet, and agreeing to it in
a meeting is not BU's call to make alone.

## Safety

Every query here is a `SELECT`. The runner refuses anything else and opens the
transaction read-only, so a demo cannot modify production even by accident. Nothing
here writes a file unless you pass `--output`, and no production rows belong in this
repository — see the `discovery/output/` note in [.gitignore](../../.gitignore).
