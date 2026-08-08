#!/usr/bin/env python3
"""
Catch documentation that has drifted away from the artifacts it describes.

Documentation goes stale quietly. The Award README claimed 66 relationships for two
commits after the CSV grew to 108, and nothing caught it. This does, without touching
the database:

  links      every relative markdown link resolves
  paths      every file and SQL path mentioned in prose exists
  counts     relationship, UI field and child-collection counts match the CSVs
  mermaid    fences are balanced and declare a diagram type
  freshness  artifact hashes still match docs/provenance.json
  style      the phrases CLAUDE.md rules out do not appear
  status     module status lines are consistent between root and module docs

Exit code is non-zero if anything fails, so it can gate a commit or run in CI.
"""

import csv
import hashlib
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

BANNED = [
    "it was determined", "it was observed", "an analysis was conducted",
    "the artifact provides", "delineates", "it is imperative",
    "implementation facilitates", "the aforementioned", "leverage this",
    "downstream consumers", "methodology ensures", "consumers should",
]

MODULES = {
    "award": ("AWARD_GRAPH.csv", "AWARD_FRONTEND_DATABASE_MAPPING.csv"),
    "proposal": ("PROPOSAL_GRAPH.csv", "PROPOSAL_FRONTEND_DATABASE_MAPPING.csv"),
    "subaward": ("SUBAWARD_GRAPH.csv", "SUBAWARD_FRONTEND_DATABASE_MAPPING.csv"),
    "negotiation": ("NEGOTIATION_GRAPH.csv", "NEGOTIATION_FRONTEND_DATABASE_MAPPING.csv"),
}

fail, warn = [], []


def md_files():
    for p in REPO.rglob("*.md"):
        if ".git" in p.parts or ".venv" in p.parts or "build" in p.parts:
            continue
        yield p


def check_links():
    for p in md_files():
        text = p.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"\[[^\]]*\]\(([^)]+)\)", text):
            target = m.group(1).split("#")[0].strip()
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            if not (p.parent / target).resolve().exists():
                fail.append(f"broken link in {p.relative_to(REPO)}: {target}")


def check_paths():
    # Backtick-quoted things that look like repo paths should exist.
    pat = re.compile(r"`((?:modules|scripts|discovery|reference|docs)/[\w./-]+)`")
    for p in md_files():
        for m in pat.finditer(p.read_text(encoding="utf-8", errors="replace")):
            t = m.group(1).rstrip("/.")
            if t.endswith(("*", ">")) or "<" in t:
                continue
            if not (REPO / t).exists():
                fail.append(f"missing path in {p.relative_to(REPO)}: {t}")


def check_counts():
    for mod, (graph, fm) in MODULES.items():
        d = REPO / "modules" / mod
        rows = list(csv.DictReader((d / graph).open(encoding="utf-8")))
        edges = len(rows)
        exposed = sum(1 for r in rows if r["HURON_EXPOSE"] == "Y")
        fields = sum(1 for _ in csv.DictReader((d / fm).open(encoding="utf-8")))

        sqls = sorted((d / "sql").glob("*.sql"))
        children = len([f for f in sqls
                        if f.name != f"huron_{mod}.sql" and "validation" not in f.name])

        for doc in (d / "README.md", d / f"{graph[:-4]}.md"):
            if not doc.exists():
                continue
            text = doc.read_text(encoding="utf-8", errors="replace")
            for label, actual, pat in (
                ("relationships", edges, r"(\d+) relationships"),
                ("exposed", exposed, r"(\d+) exposed"),
                ("UI fields", fields, r"(\d+) UI fields"),
                ("child collections", children, r"(\d+) child collections"),
            ):
                for m in re.finditer(pat, text):
                    if int(m.group(1)) != actual:
                        fail.append(
                            f"{doc.relative_to(REPO)} says {m.group(1)} {label}, "
                            f"actual is {actual}")


def check_mermaid():
    for p in md_files():
        lines = p.read_text(encoding="utf-8", errors="replace").split("\n")
        opens = [i for i, l in enumerate(lines) if l.strip().startswith("```mermaid")]
        for i in opens:
            close = next((j for j in range(i + 1, len(lines))
                          if lines[j].strip() == "```"), None)
            if close is None:
                fail.append(f"unclosed mermaid fence in {p.relative_to(REPO)} line {i+1}")
                continue
            body = "\n".join(lines[i + 1:close]).strip()
            if not re.match(r"^(graph|flowchart|sequenceDiagram|erDiagram|classDiagram)",
                            body):
                fail.append(f"mermaid block in {p.relative_to(REPO)} line {i+1} "
                            f"declares no diagram type")


def check_freshness():
    man = REPO / "docs/provenance.json"
    if not man.exists():
        warn.append("docs/provenance.json missing - run scripts/build_provenance.py")
        return
    data = json.loads(man.read_text())
    for a in data.get("artifacts", []):
        p = REPO / a["artifact"]
        if not p.exists():
            fail.append(f"provenance lists a missing artifact: {a['artifact']}")
            continue
        now = hashlib.sha256(p.read_bytes()).hexdigest()[:16]
        if now != a["sha256"]:
            warn.append(f"{a['artifact']} changed since provenance was written "
                        f"- re-run scripts/build_provenance.py")


def check_style():
    for p in md_files():
        if p.name == "CLAUDE.md":   # it lists the banned phrases on purpose
            continue
        low = p.read_text(encoding="utf-8", errors="replace").lower()
        for phrase in BANNED:
            if phrase in low:
                fail.append(f"{p.relative_to(REPO)} uses a phrase CLAUDE.md rules out: "
                            f"\"{phrase}\"")


def check_status():
    root = (REPO / "README.md").read_text(encoding="utf-8", errors="replace")
    for mod in MODULES:
        doc = REPO / "modules" / mod / "README.md"
        if not doc.exists():
            continue
        text = doc.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"Status:\s*\*\*(.+?)\*\*", text)
        if not m:
            warn.append(f"{doc.relative_to(REPO)} has no Status line")
            continue
        state = m.group(1).split("·")[0].strip()
        if state.lower() not in root.lower():
            fail.append(f"{mod} status \"{state}\" does not appear in the root README")


def main():
    for fn in (check_links, check_paths, check_counts, check_mermaid,
               check_freshness, check_style, check_status):
        fn()

    print("=" * 62)
    print("DOCUMENTATION CHECKS")
    print("=" * 62)
    print(f"Failures : {len(fail)}")
    for f in fail[:40]:
        print(f"   FAIL  {f}")
    if len(fail) > 40:
        print(f"   ... +{len(fail)-40} more")
    print(f"Warnings : {len(warn)}")
    for w in warn[:20]:
        print(f"   WARN  {w}")
    print("=" * 62)
    print("RESULT:", "PASS" if not fail else "FAIL")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
