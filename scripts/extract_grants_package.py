#!/usr/bin/env python3
"""
Produce the per-table data files for the Huron Grants discovery package.

Reads 02_table_manifest.csv + 01_data_dictionary.csv and, for every table marked
FULL or SAMPLE, generates a SELECT and runs it through the controlled read-only
production runner (scripts/kc_prod_readonly_query.py). No other DB path is used and
no DML/DDL is ever emitted.

Column handling:
  CLOB      -> DBMS_LOB.SUBSTR(col, 1000, 1): mapping needs the text shape, not the
               whole narrative
  BLOB/RAW  -> DBMS_LOB.GETLENGTH(col): file content is useless to a field mapper,
               its presence and size are not
  PII       -> sensitive columns are redacted; the column stays in the file so the
               structure is visible, but no personal value leaves BU

SAMPLE tables are spread across the whole table with ROW_NUMBER()/MOD rather than
ROWNUM, so the sample is not just the physically-first rows. ALL columns and ALL
lineage keys are retained -- only the row count is reduced.
"""

import argparse
import csv
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

RUNNER = Path("scripts/kc_prod_readonly_query.py")
PYTHON = Path(".venv/bin/python")

SAMPLE_ROWS = 1000
PII_SAMPLE_ROWS = 100

# Columns whose values must not leave BU even in a sample.
SENSITIVE = re.compile(
    r"SSN|SOCIAL_SECURITY|DATE_OF_BIRTH|\bDOB\b|BIRTH|PASSWORD|PASSWD|SALARY|"
    r"BANK|ACCOUNT_NUMBER_BANK|TAX_ID|PASSPORT|VISA|CITIZENSHIP|GENDER|RACE|"
    r"ETHNIC|DISABILITY|VETERAN|HANDICAP",
    re.I,
)
# Personal-contact columns: redacted inside PII tables, kept elsewhere.
CONTACT = re.compile(
    r"FIRST_NAME|LAST_NAME|MIDDLE_NAME|FULL_NAME|USER_NAME|EMAIL|PHONE|FAX|"
    r"ADDRESS_LINE|HOME_|MOBILE|PAGER",
    re.I,
)

DOMAIN_DIR = {
    "Award": "award",
    "Institutional Proposal": "institutional_proposal",
    "Proposal / pre-award": "proposal",
    "Subaward": "subaward",
    "Negotiation": "negotiation",
    "Sponsor": "reference",
    "Organization": "reference",
    "Unit": "reference",
    "Reference / lookup": "reference",
    "BU custom fields": "bu_custom",
}


def column_expr(table, col, data_type, is_pii):
    """Return the SELECT expression for one column."""
    base = data_type.split("(")[0].strip().upper()
    quoted = f'"{col}"'

    if is_pii and (SENSITIVE.search(col) or CONTACT.search(col)):
        return f"CAST('REDACTED' AS VARCHAR2(20)) AS {quoted}"
    if SENSITIVE.search(col):
        return f"CAST('REDACTED' AS VARCHAR2(20)) AS {quoted}"

    if base in ("BLOB", "RAW", "LONG RAW", "BFILE"):
        return f"DBMS_LOB.GETLENGTH({quoted}) AS {quoted}"
    if base in ("CLOB", "NCLOB"):
        return f"DBMS_LOB.SUBSTR({quoted}, 1000, 1) AS {quoted}"
    if base == "XMLTYPE":
        return f"SUBSTR(XMLSERIALIZE(CONTENT {quoted}), 1, 1000) AS {quoted}"
    if base == "DATE" or base.startswith("TIMESTAMP"):
        return f"TO_CHAR({quoted}, 'YYYY-MM-DD HH24:MI:SS') AS {quoted}"
    return quoted


def build_sql(table, columns, extract_type, row_count, is_pii):
    exprs = ",\n       ".join(columns)
    if extract_type == "FULL":
        return f"SELECT {exprs}\nFROM   {table}"

    target = PII_SAMPLE_ROWS if is_pii else SAMPLE_ROWS
    step = max(1, row_count // target)
    # Spread the sample across the whole table instead of taking the first N rows.
    return (
        f"SELECT {exprs}\n"
        f"FROM   (SELECT t.*, ROW_NUMBER() OVER (ORDER BY ROWID) AS rn__\n"
        f"        FROM   {table} t)\n"
        f"WHERE  MOD(rn__, {step}) = 0\n"
        f"AND    ROWNUM <= {target}"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--dictionary", required=True)
    ap.add_argument("--out-root", required=True)
    ap.add_argument("--sql-root", required=True)
    ap.add_argument("--only-domain")
    args = ap.parse_args()

    manifest = list(csv.DictReader(open(args.manifest, encoding="utf-8")))
    cols = defaultdict(list)
    for r in csv.DictReader(open(args.dictionary, encoding="utf-8")):
        cols[r["TABLE_NAME"]].append(r)

    out_root, sql_root = Path(args.out_root), Path(args.sql_root)
    results = []

    todo = [m for m in manifest if m["EXTRACT_TYPE"] in ("FULL", "SAMPLE")]
    if args.only_domain:
        todo = [m for m in todo if m["DOMAIN"] == args.only_domain]

    for i, m in enumerate(todo, 1):
        table = m["TABLE_NAME"]
        is_pii = m["CONTAINS_PII"] == "Y"
        exprs = [
            column_expr(table, c["COLUMN_NAME"], c["DATA_TYPE"], is_pii)
            for c in sorted(cols[table], key=lambda c: int(c["COLUMN_ID"]))
        ]
        if not exprs:
            continue

        sql = build_sql(table, exprs, m["EXTRACT_TYPE"], int(m["ROW_COUNT"]), is_pii)
        sub = DOMAIN_DIR.get(m["DOMAIN"], "other")

        sql_path = sql_root / sub / f"{table.lower()}.sql"
        sql_path.parent.mkdir(parents=True, exist_ok=True)
        sql_path.write_text(sql + "\n", encoding="utf-8")

        out_path = out_root / sub / f"{table.lower()}.csv"
        out_path.parent.mkdir(parents=True, exist_ok=True)

        proc = subprocess.run(
            [str(PYTHON), str(RUNNER), "--file", str(sql_path), "--output", str(out_path)],
            capture_output=True, text=True,
        )
        ok = proc.returncode == 0
        written = ""
        if ok:
            mm = re.search(r"Wrote ([\d,]+) rows", proc.stdout)
            written = mm.group(1) if mm else ""
        else:
            err = proc.stderr.strip().splitlines()
            written = err[-1][:160] if err else "failed"

        results.append({
            "DOMAIN": m["DOMAIN"], "TABLE_NAME": table,
            "EXTRACT_TYPE": m["EXTRACT_TYPE"], "FILE": str(out_path),
            "STATUS": "OK" if ok else "FAILED", "ROWS_WRITTEN": written,
        })
        print(f"[{i}/{len(todo)}] {table:38s} {m['EXTRACT_TYPE']:6s} "
              f"{'OK' if ok else 'FAILED'} {written}", flush=True)

    log = out_root / "02_extract_log.csv"
    with log.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=[
            "DOMAIN", "TABLE_NAME", "EXTRACT_TYPE", "FILE", "STATUS", "ROWS_WRITTEN"])
        w.writeheader()
        w.writerows(results)

    failed = [r for r in results if r["STATUS"] != "OK"]
    print(f"\nextracted {len(results) - len(failed)}/{len(results)} tables; "
          f"{len(failed)} failed -> {log}")
    for r in failed:
        print(f"   FAILED {r['TABLE_NAME']}: {r['ROWS_WRITTEN']}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
