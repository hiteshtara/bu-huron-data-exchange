# Live demo pack

Eight read-only queries for showing Huron what is in KC and what shape it comes out
in, plus what to say while each one runs. Built for the BU/Huron review session.

The centre of this demo is **demo 7** — one Award as a single nested JSON document
with its source keys intact. If only one query gets run, run that one. Everything
else either sets it up or backs it up.

**Run all eight yourself before the meeting.** They use the same tables and the same
version-selection rules as the module SQL, but they have not been executed against
production — do not demo a query you have not seen return. Demos 4 and 7 need an
award number you have checked.

## Before the meeting

Confirm the connection, and confirm it comes back read-only:

```bash
.venv/bin/python scripts/kc_prod_readonly_query.py --test
```

You want `Database: KUALI` and `Mode: READ ONLY`. Full setup is in
[ONBOARDING.md](../ONBOARDING.md).

Then run each one once and note what comes back, so nothing surprises you on screen:

```bash
for q in docs/demo/*.sql; do
  echo "== $q"
  .venv/bin/python scripts/kc_prod_readonly_query.py --file "$q" --limit 25
done
```

The JSON from demo 7 is a single CLOB in one column. Pipe it somewhere readable
before the meeting so you know it is well-formed and you know how long it is:

```bash
.venv/bin/python scripts/kc_prod_readonly_query.py \
    --file docs/demo/07_award_as_json_document.sql --output /tmp/award.csv
```

## Suggested running order

The order below leads with what Huron receives, and keeps the source-side reasoning
in reserve for when it is asked for.

| Order | Query | What it shows | The line to say |
|---|---|---|---|
| 1 | [01 population](01_population_reconciliation.sql) | All four objects, physical rows against business records | "This is the whole Grants conversion in one result." |
| 2 | **[07 Award as a JSON document](07_award_as_json_document.sql)** | One complete Award as a nested payload | "This is what you would receive. One award, its people, money, terms, reviews and BU custom fields, in one document — and every KC key still in it." |
| 3 | [08 the same thing as a feed](08_award_json_feed.sql) | One row per award, each a complete document | "Nothing about the shape changes between one and 43,202. Drop the limit and that is the population." |
| 4 | [04 one award hydrated](04_one_award_end_to_end.sql) | Child-collection counts, and what a flat join would have cost | "That last column is why it ships as a document rather than one wide row." |
| 5 | [03 award families](03_award_families.sql) | The family-size distribution behind the 15,729 | "43,202 awards, 15,729 funded projects. Which one HRS expects is D-17, and the document carries both." |
| 6 | [05 subaward funding](05_subaward_to_award_funding.sql) | Funding links pointing at superseded award versions | "Three quarters point at a version that is no longer current. We kept what KC recorded. That is D-01." |
| 7 | [06 BU custom fields](06_bu_custom_fields.sql) | The EAV model resolved to BU's real field labels | "These arrive in the document by name, not as attribute 1542." |
| 8 | [02 why MAX(SEQUENCE) is wrong](02_why_max_sequence_is_wrong.sql) | Award numbers with two rows at the same highest sequence | Keep in reserve. It answers "how do you know you picked the right row?" if someone asks. |

If time is short: **1, 7, 8**. That is scale, shape, and scale-of-shape, and it is the
whole reassurance argument.

## The point demo 7 is making

Two things to put a finger on while the JSON is on screen.

**`sourceKeys`.** Every KC identifier needed to tie the loaded record back to KC and
to re-link it to other objects travels inside the payload. It is not consumed by the
export. That is D-20 made concrete rather than discussed — the half BU controls is
already done, and what is left is where those keys live on the Huron side.

**`hierarchy`.** `rootAwardNumber` and `parentAwardNumber` ride along with every
award, so the family structure survives whichever grain HRS picks. BU does not have
to know the answer to D-17 to hand over data that works either way.

**And the honest part.** The field names in that document are BU's, not Huron's. HRS
has not told us its object model, so this is the source document BU can emit — not a
claim about what HRS expects. Reshaping the SELECT to match a target schema is a
day's work once there is a schema to match; it is not a redesign. Say that plainly
rather than implying the mapping is further along than it is.

## Talking about connectivity

This will come up, and precision helps more than improvisation.

**What exists today.** BU developers query KC production through
`scripts/kc_prod_readonly_query.py`. That runner accepts only `SELECT` and `WITH`,
opens the transaction read-only, and reads its password from the local Keychain.

**What that is not.** It is not a connection BU can hand to Huron. Every one of those
controls is a property of the runner, not of the account — a different client using
the same connection details would inherit none of them. Worth saying out loud,
because "BU already connects to production every day" sounds like it answers the
access question and it does not.

So the demo is BU running queries on screen. It is not a walkthrough of how Huron
would connect, because **no Huron access path has been provisioned and the delivery
method is still an open joint decision (D-18).** If Huron asks how they get the data,
the answer is the four options in [HURON_CONNECTIVITY.md](../HURON_CONNECTIVITY.md)
and the five questions BU needs answered — not credentials, a tunnel, or a host name.

Demo 8 is useful here: whatever delivery option gets chosen, those documents are what
travels. Files, a staging table or an endpoint changes the transport, not the payload.

## Safety

Every query here is a `SELECT`. The runner refuses anything else and opens the
transaction read-only, so a demo cannot modify production even by accident. Nothing
writes a file unless you pass `--output`, and no production rows belong in this
repository — see the `discovery/output/` note in [.gitignore](../../.gitignore).
