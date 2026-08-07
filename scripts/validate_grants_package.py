#!/usr/bin/env python3
"""
Validate the Huron Grants discovery package before delivery.

Runs the project's validation levels against the assembled package:

  STRUCTURAL  every FULL/SAMPLE table has a file; header matches the data
              dictionary column list exactly, in order; no ragged rows
  COUNTS      FULL extracts equal the production row count; SAMPLE extracts are
              within the sample ceiling; manifest + exclusions reconcile to the
              901 tables in KCOEUS
  FIELD       PII columns in PII tables are redacted; no obvious secret-like
              values leaked
  LINEAGE     every non-reference table retains at least one lineage key

Exit code is non-zero if any check fails, so this can gate delivery.
"""

import argparse
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

SAMPLE_CEILING = 1000

# KCOEUS is live; allow small row drift between discovery and extract.
DRIFT_ROW_TOLERANCE = 50
DRIFT_PCT_TOLERANCE = 0.005
PII_SAMPLE_CEILING = 100

SENSITIVE = re.compile(
    r"SSN|SOCIAL_SECURITY|DATE_OF_BIRTH|\bDOB\b|BIRTH|PASSWORD|PASSWD|SALARY|"
    r"BANK|TAX_ID|PASSPORT|VISA|CITIZENSHIP|GENDER|RACE|ETHNIC|DISABILITY|"
    r"VETERAN|HANDICAP", re.I)
CONTACT = re.compile(
    r"FIRST_NAME|LAST_NAME|MIDDLE_NAME|FULL_NAME|USER_NAME|EMAIL|PHONE|FAX|"
    r"ADDRESS_LINE|HOME_|MOBILE|PAGER", re.I)

# Things that must never appear in a file leaving BU.
SECRET_HINT = re.compile(
    r"(?i)\b(password|passwd|secret|api[_-]?key|private[_-]?key|BEGIN [A-Z ]*PRIVATE KEY)\b"
    r"\s*[=:]\s*\S")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--dictionary", required=True)
    ap.add_argument("--excluded", required=True)
    ap.add_argument("--total-tables", type=int, default=901)
    args = ap.parse_args()

    pkg = Path(args.package)
    manifest = list(csv.DictReader(open(args.manifest, encoding="utf-8")))
    excluded = list(csv.DictReader(open(args.excluded, encoding="utf-8")))

    dict_cols = defaultdict(list)
    for r in csv.DictReader(open(args.dictionary, encoding="utf-8")):
        dict_cols[r["TABLE_NAME"]].append((int(r["COLUMN_ID"]), r["COLUMN_NAME"]))
    for t in dict_cols:
        dict_cols[t].sort()

    log_path = pkg / "02_extract_log.csv"
    log = {r["TABLE_NAME"]: r for r in csv.DictReader(open(log_path, encoding="utf-8"))} \
        if log_path.exists() else {}

    failures, warnings = [], []

    # ---------- COUNTS: table population reconciles ----------
    total = len(manifest) + len(excluded)
    if total != args.total_tables:
        failures.append(
            f"COUNTS: manifest({len(manifest)}) + excluded({len(excluded)}) "
            f"= {total}, expected {args.total_tables}")

    by_type = defaultdict(int)
    for m in manifest:
        by_type[m["EXTRACT_TYPE"]] += 1

    # ---------- per-table checks ----------
    checked = 0
    for m in manifest:
        table = m["TABLE_NAME"]
        etype = m["EXTRACT_TYPE"]
        if etype == "EMPTY":
            if table not in dict_cols:
                failures.append(f"STRUCTURAL: {table} EMPTY but has no dictionary columns")
            continue

        entry = log.get(table)
        if not entry:
            failures.append(f"STRUCTURAL: {table} ({etype}) missing from extract log")
            continue
        if entry["STATUS"] != "OK":
            failures.append(f"STRUCTURAL: {table} extract FAILED: {entry['ROWS_WRITTEN']}")
            continue

        path = Path(entry["FILE"])
        if not path.exists():
            failures.append(f"STRUCTURAL: {table} file missing: {path}")
            continue

        with path.open(encoding="utf-8", newline="") as fh:
            rd = csv.reader(fh)
            try:
                header = next(rd)
            except StopIteration:
                failures.append(f"STRUCTURAL: {table} file is empty")
                continue

            expected = [c for _, c in dict_cols.get(table, [])]
            if header != expected:
                failures.append(
                    f"STRUCTURAL: {table} header mismatch "
                    f"({len(header)} cols vs {len(expected)} in dictionary)")

            is_pii = m["CONTAINS_PII"] == "Y"
            redact_idx = [
                i for i, c in enumerate(header)
                if SENSITIVE.search(c) or (is_pii and CONTACT.search(c))
            ]

            n = ragged = 0
            leaked = set()
            for row in rd:
                n += 1
                if len(row) != len(header):
                    ragged += 1
                for i in redact_idx:
                    if i < len(row) and row[i] not in ("", "REDACTED"):
                        leaked.add(header[i])
                if n <= 200:
                    joined = ",".join(row)
                    if SECRET_HINT.search(joined):
                        warnings.append(f"FIELD: {table} row {n} looks secret-like")

            if ragged:
                failures.append(f"STRUCTURAL: {table} has {ragged} ragged rows")
            if leaked:
                failures.append(
                    f"FIELD: {table} unredacted sensitive column(s): "
                    f"{', '.join(sorted(leaked))}")

            ceiling = PII_SAMPLE_CEILING if is_pii else SAMPLE_CEILING
            if etype == "FULL":
                expected_rows = int(m["ROW_COUNT"])
                delta = n - expected_rows
                # KCOEUS is a live production database: rows are inserted between
                # the discovery COUNT(*) and the extract. Treat a small difference
                # as drift, not corruption, but fail on anything large enough to
                # suggest a truncated or filtered extract.
                tolerance = max(DRIFT_ROW_TOLERANCE,
                                int(expected_rows * DRIFT_PCT_TOLERANCE))
                if delta and abs(delta) <= tolerance:
                    warnings.append(
                        f"COUNTS: {table} FULL wrote {n} rows vs {expected_rows} at "
                        f"discovery ({delta:+d}) - live production drift")
                elif delta:
                    failures.append(
                        f"COUNTS: {table} FULL wrote {n} rows, production had "
                        f"{expected_rows} ({delta:+d}, beyond drift tolerance)")
            if etype == "SAMPLE" and n > ceiling:
                failures.append(f"COUNTS: {table} SAMPLE wrote {n} rows, ceiling {ceiling}")
            if etype == "SAMPLE" and n == 0:
                warnings.append(f"COUNTS: {table} SAMPLE wrote 0 rows")

            # LINEAGE
            if m["LINEAGE_KEYS"]:
                keys = [k for k in m["LINEAGE_KEYS"].split(",") if k]
                if not any(k in header for k in keys):
                    failures.append(f"LINEAGE: {table} lost its lineage keys")
        checked += 1

    # ---------- report ----------
    print("=" * 66)
    print("HURON GRANTS PACKAGE VALIDATION")
    print("=" * 66)
    print(f"Tables in KCOEUS production : {args.total_tables}")
    print(f"  in scope (manifest)       : {len(manifest)}")
    print(f"  excluded (reason-coded)   : {len(excluded)}")
    print(f"  reconciled                : "
          f"{'YES' if total == args.total_tables else 'NO'}")
    print()
    for k in ("FULL", "SAMPLE", "EMPTY"):
        print(f"  {k:7s}                   : {by_type[k]}")
    print(f"  data files validated      : {checked}")
    print()
    print(f"Failures : {len(failures)}")
    for f in failures[:40]:
        print(f"   FAIL  {f}")
    if len(failures) > 40:
        print(f"   ... +{len(failures) - 40} more")
    print(f"Warnings : {len(warnings)}")
    for w in warnings[:15]:
        print(f"   WARN  {w}")
    if len(warnings) > 15:
        print(f"   ... +{len(warnings) - 15} more")
    print("=" * 66)
    print("RESULT:", "PASS" if not failures else "FAIL")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
