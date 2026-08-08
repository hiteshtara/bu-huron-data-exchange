#!/usr/bin/env python3
"""
Record where the artifacts in this repo came from and when.

Counts like "43,202 awards" read as permanent facts, but production moves. This writes
docs/PROVENANCE.md and docs/provenance.json so every number in the repo can be tied to a
date, a database, a source tree and a repository revision.

Run it after regenerating any artifact:

    .venv/bin/python scripts/build_provenance.py \
        --source ~/Downloads/kuali-research-bu-master \
        --validated-on 2026-08-07
"""

import argparse
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path

ARTIFACTS = [
    "reference/KUALI_FIELD_DICTIONARY.csv",
    "modules/award/AWARD_GRAPH.csv",
    "modules/award/AWARD_FRONTEND_DATABASE_MAPPING.csv",
    "modules/proposal/PROPOSAL_GRAPH.csv",
    "modules/proposal/PROPOSAL_FRONTEND_DATABASE_MAPPING.csv",
    "modules/subaward/SUBAWARD_GRAPH.csv",
    "modules/subaward/SUBAWARD_FRONTEND_DATABASE_MAPPING.csv",
    "modules/negotiation/NEGOTIATION_GRAPH.csv",
    "modules/negotiation/NEGOTIATION_FRONTEND_DATABASE_MAPPING.csv",
    "discovery/01_data_dictionary.csv",
    "discovery/02_table_manifest.csv",
]

# Headline counts we quote in the documentation, and where they come from.
POPULATIONS = [
    ("Award", "AWARD", 282_468, 43_202),
    ("Institutional Proposal", "PROPOSAL", 130_122, 36_863),
    ("Subaward", "SUBAWARD", 93_061, 3_466),
    ("Negotiation", "NEGOTIATION", 11_842, 11_842),
]


def sh(*args, cwd=None):
    try:
        return subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                              check=True).stdout.strip()
    except Exception:
        return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, help="Kuali source root")
    ap.add_argument("--validated-on", required=True, help="YYYY-MM-DD the counts were taken")
    ap.add_argument("--database", default="KCOEUS on prod.db.kuali.research.bu.edu")
    args = ap.parse_args()

    repo = Path(__file__).resolve().parent.parent
    src = Path(args.source).expanduser()

    repo_rev = sh("git", "rev-parse", "HEAD", cwd=repo)
    repo_short = repo_rev[:12]
    dirty = bool(sh("git", "status", "--porcelain", cwd=repo))

    # The Kuali tree is an extracted zip, so there is usually no SHA to read. Record
    # what can actually be proven instead of inventing a revision.
    src_rev = sh("git", "rev-parse", "HEAD", cwd=src) if (src / ".git").exists() else ""
    pom = (src / "pom.xml")
    pom_version = ""
    if pom.exists():
        m = re.search(r"<version>([^<]+)</version>", pom.read_text(errors="replace"))
        pom_version = m.group(1) if m else ""

    rows = []
    for rel in ARTIFACTS:
        p = repo / rel
        if not p.exists():
            continue
        data = p.read_bytes()
        with p.open(encoding="utf-8") as fh:
            n = sum(1 for _ in csv.reader(fh)) - 1
        rows.append({
            "artifact": rel,
            "rows": n,
            "sha256": hashlib.sha256(data).hexdigest()[:16],
        })

    manifest = {
        "validated_against_production": args.validated_on,
        "database": args.database,
        "repository_revision": repo_rev,
        "repository_clean": not dirty,
        "kuali_source": {
            "path": str(src),
            "branch": "bu-master",
            "revision": src_rev or None,
            "revision_note": None if src_rev else
                "extracted from a zip, so no git revision is available",
            "pom_version": pom_version or None,
        },
        "populations": [
            {"module": m, "table": t, "physical_rows": p, "business_records": b}
            for m, t, p, b in POPULATIONS
        ],
        "artifacts": rows,
    }

    (repo / "docs").mkdir(exist_ok=True)
    (repo / "docs/provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")

    src_line = (f"`{src_rev[:12]}`" if src_rev
                else "not available — the source is an extracted zip, not a clone")
    lines = [
        "# Where these numbers came from",
        "",
        "Every count in this repo is a measurement, not a permanent fact. Production keeps",
        "moving, so this page records when we took the measurements and what we took them",
        "against. `provenance.json` next to it is the machine-readable version.",
        "",
        "Regenerate it with `scripts/build_provenance.py` after rebuilding any artifact.",
        "",
        "## What we measured against",
        "",
        "| | |",
        "|---|---|",
        f"| Validated against production | **{args.validated_on}** |",
        f"| Database | {args.database} |",
        f"| Repository revision | `{repo_short}` |",
        f"| Kuali source branch | `bu-master` |",
        f"| Kuali source revision | {src_line} |",
        f"| Kuali `pom.xml` version | `{pom_version or 'unknown'}` |",
        "",
        "We could not pin the Kuali source to a commit. The tree came from",
        "`kuali-research-bu-master.zip` rather than a clone, so there is no SHA to read. The",
        "branch name and the `pom.xml` version are what we can actually prove. If this needs",
        "to be exact later, cloning the fork instead of downloading the zip would fix it.",
        "",
        "## Population counts, as measured",
        "",
        "| Module | Table | Physical rows | Business records |",
        "|---|---|---|---|",
    ]
    for m, t, p, b in POPULATIONS:
        note = " (not versioned)" if p == b else ""
        lines.append(f"| {m} | `{t}` | {p:,} | {b:,}{note} |")
    lines += [
        "",
        "These move. Award gained four rows during a single working session while we were",
        "modelling it, which is why the validation queries tolerate small drift rather than",
        "treating it as a defect.",
        "",
        "## Generated artifacts",
        "",
        "| Artifact | Rows | SHA-256 (first 16) |",
        "|---|---|---|",
    ]
    for r in rows:
        lines.append(f"| `{r['artifact']}` | {r['rows']:,} | `{r['sha256']}` |")
    lines += [
        "",
        "The hashes are here so you can tell whether a CSV still matches the documentation",
        "that describes it. `scripts/check_docs.py` compares them.",
        "",
    ]
    (repo / "docs/PROVENANCE.md").write_text("\n".join(lines))

    print(f"repository revision : {repo_short}{' (dirty)' if dirty else ''}")
    print(f"kuali source        : {src_rev[:12] if src_rev else 'no SHA (zip)'}"
          f"  pom {pom_version or '?'}")
    print(f"artifacts recorded  : {len(rows)}")
    print("wrote docs/PROVENANCE.md and docs/provenance.json")


if __name__ == "__main__":
    main()
