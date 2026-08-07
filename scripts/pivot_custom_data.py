#!/usr/bin/env python3
"""
Pivot a normalized BU custom-data extract into a mapping-friendly wide file.

BU's custom fields are stored EAV-style: the physical column is a generic VALUE and
the logical field identity is CUSTOM_ATTRIBUTE_ID. Handing Huron the raw EAV rows
forces their tooling to infer meaning from an integer. This turns

    AWARD_NUMBER | CUSTOM_ATTRIBUTE_ID | VALUE
    100001-00001 | 1234                | Yes

into

    AWARD_NUMBER | <Custom Field Label 1234> | ...
    100001-00001 | Yes                       | ...

The normalized extract is kept alongside it for lineage and completeness -- this is
an additional representation, not a replacement.

Each pivot emits a companion *_columns.csv describing every generated header, so no
header is ever ambiguous.
"""

import argparse
import csv
import re
from collections import OrderedDict, defaultdict
from pathlib import Path

# Records are identified by number + sequence; a record can hold one value per
# attribute per sequence.
KEY_COLUMNS = ["MODULE", "RECORD_NUMBER", "RECORD_ID", "SEQUENCE_NUMBER"]


def sanitize(label: str, fallback: str) -> str:
    """Make a clear, file-safe CSV header out of a custom-attribute label."""
    base = (label or "").strip() or (fallback or "").strip()
    base = re.sub(r"[^0-9A-Za-z]+", "_", base).strip("_")
    return (base or "CUSTOM_FIELD").upper()[:60]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="normalized custom-data CSV")
    ap.add_argument("--output", required=True, help="wide/pivoted CSV")
    args = ap.parse_args()

    src = Path(args.input)
    rows = list(csv.DictReader(src.open(encoding="utf-8")))
    if not rows:
        print(f"{src.name}: no rows, nothing to pivot")
        return

    # Build the header set from the attribute definitions actually present.
    attrs = {}
    for r in rows:
        aid = r["CUSTOM_ATTRIBUTE_ID"]
        if aid not in attrs:
            attrs[aid] = {
                "id": aid,
                "name": r.get("CUSTOM_ATTRIBUTE_NAME", ""),
                "label": r.get("CUSTOM_ATTRIBUTE_LABEL", ""),
                "group": r.get("GROUP_NAME", ""),
                "data_type": r.get("DATA_TYPE", ""),
                "max_length": r.get("MAX_LENGTH", ""),
            }

    # Assign unique headers; disambiguate collisions with the attribute id so the
    # mapping stays one-to-one.
    used = defaultdict(list)
    for a in attrs.values():
        used[sanitize(a["label"], a["name"])].append(a)
    for header, group in used.items():
        for a in group:
            a["header"] = header if len(group) == 1 else f"{header}_{a['id']}"

    ordered = sorted(attrs.values(), key=lambda a: (a["group"] or "", a["header"]))
    headers = [a["header"] for a in ordered]
    by_id = {a["id"]: a["header"] for a in ordered}

    # Pivot: one output row per (record, sequence).
    pivot = OrderedDict()
    collisions = 0
    for r in rows:
        key = tuple(r.get(k, "") for k in KEY_COLUMNS)
        rec = pivot.setdefault(key, {k: r.get(k, "") for k in KEY_COLUMNS})
        col = by_id[r["CUSTOM_ATTRIBUTE_ID"]]
        if col in rec and rec[col] != (r.get("CUSTOM_VALUE") or ""):
            collisions += 1
        rec[col] = r.get("CUSTOM_VALUE") or ""

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=KEY_COLUMNS + headers)
        w.writeheader()
        for rec in pivot.values():
            w.writerow({**{h: "" for h in headers}, **rec})

    # Companion header dictionary so every generated column is self-describing.
    cols_out = out.with_name(out.stem + "_columns.csv")
    with cols_out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow([
            "CSV_COLUMN", "CUSTOM_ATTRIBUTE_ID", "CUSTOM_ATTRIBUTE_NAME",
            "CUSTOM_ATTRIBUTE_LABEL", "GROUP_NAME", "DATA_TYPE", "MAX_LENGTH",
            "SOURCE",
        ])
        for k in KEY_COLUMNS:
            w.writerow([k, "", "", "", "", "", "", "record key from source table"])
        for a in ordered:
            w.writerow([
                a["header"], a["id"], a["name"], a["label"], a["group"],
                a["data_type"], a["max_length"],
                "KCOEUS.CUSTOM_ATTRIBUTE (production configuration)",
            ])

    print(f"{out.name}: {len(pivot):,} records x {len(headers)} custom fields"
          + (f"  [{collisions} value collisions]" if collisions else ""))


if __name__ == "__main__":
    main()
