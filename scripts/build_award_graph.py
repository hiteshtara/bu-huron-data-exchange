#!/usr/bin/env python3
"""
Derive the KC Award business-object graph from the Kuali source, not from table names.

Starts at org.kuali.kra.award.home.Award and walks the OJB/JPA relationship model:

  reference-descriptor   -> MANY_TO_ONE (or ONE_TO_ONE when the FK is the parent PK)
  collection-descriptor  -> ONE_TO_MANY

Each edge is resolved to real KCOEUS tables and annotated with the production row
count, so the graph reflects what BU actually holds rather than what KC supports.

Emits reference/award/AWARD_GRAPH.csv. The narrative AWARD_GRAPH.md is written
separately.
"""

import argparse
import csv
import importlib.util
import re
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _load_parsers():
    """Reuse the ORM parsers from the field-dictionary builder."""
    spec = importlib.util.spec_from_file_location(
        "kfd", HERE / "build_kuali_field_dictionary.py")
    mod = importlib.util.module_from_spec(spec)
    sys.modules["kfd"] = mod
    spec.loader.exec_module(mod)
    return mod


ROOT_CLASS = "org.kuali.kra.award.home.Award"

# Business purpose per relationship name. Anything not listed falls back to the
# child class name, so the graph stays honest about what we do and do not know.
PURPOSE = {
    "extension": "BU-specific extended Award attributes",
    "sponsor": "Sponsor of record",
    "primeSponsor": "Prime (pass-through) sponsor",
    "leadUnit": "Owning organizational unit",
    "awardStatus": "Award status decode",
    "awardType": "Award type decode",
    "activityType": "Activity type decode",
    "awardTransactionType": "Transaction type decode for the current action",
    "awardBasisOfPayment": "Basis of payment decode",
    "awardMethodOfPayment": "Method of payment decode",
    "nsfCodeBo": "NSF science code decode",
    "awardTemplate": "Award template the record was created from",
    "awardDocument": "KEW routing document header",
    "versionHistory": "Framework versioning bookkeeping",
    "projectPersons": "Key personnel on the award",
    "awardAmountInfos": "Obligated/anticipated money and dates per transaction",
    "awardCostShares": "Cost share commitments",
    "awardFandaRate": "F&A / IDC rates applied",
    "awardReportTermItems": "Required reports and their schedule",
    "awardSponsorTerms": "Sponsor terms attached to the award",
    "specialReviews": "Compliance special reviews (IRB/IACUC/etc.)",
    "awardCustomDataList": "BU custom attribute values (EAV)",
    "fundingProposals": "Institutional Proposals funding this award",
    "allFundingProposals": "Funding proposals incl. inactive",
    "awardUnitContacts": "Unit administrative contacts",
    "sponsorContacts": "Sponsor-side contacts",
    "awardComments": "Free-text comments by type",
    "awardNotepads": "Notepad entries",
    "awardAttachments": "Attachment metadata",
    "awardCloseoutItems": "Closeout checklist and dates",
    "awardApprovedSubawards": "Approved subaward authorizations",
    "approvedEquipmentItems": "Approved equipment authorizations",
    "approvedForeignTravelTrips": "Approved foreign travel authorizations",
    "keywords": "Science keywords",
    "paymentScheduleItems": "Payment schedule",
    "awardTransferringSponsors": "Transferring sponsors",
    "awardDirectFandADistributions": "Direct / F&A distribution by period",
    "awardBudgetLimits": "Budget limits",
    "awardCfdas": "CFDA / ALN numbers",
    "awardCgbList": "Contracts & Grants Billing configuration",
    "currentVersionBudgets": "Award budget versions",
    "awardCloseout": "Closeout",
    "syncChanges": "Award hierarchy sync change log",
    "syncStatuses": "Award hierarchy sync status",
    "awardNotifications": "Notification log",
    "awardReportTermRecipients": "Report recipients",
    "units": "Units the person is credited under",
    "creditSplits": "Credit split percentages",
    "unitCreditSplits": "Unit-level credit split percentages",
}

# Relationships to keep out of the Huron interface, with the reason.
EXCLUDE = {
    "awardDocument": "KEW workflow routing header - platform infrastructure, not Grants data",
    "versionHistory": "framework versioning bookkeeping, not a business relationship",
    "syncChanges": "hierarchy sync change log - operational, not conversion data",
    "syncStatuses": "hierarchy sync status - operational, not conversion data",
    "awardNotifications": "notification send log - operational",
    "awardTemplate": "authoring template the record was created from, not award content",
    "allFundingProposals": "duplicate of fundingProposals without an inverse FK",
    "awardCgbList": "Contracts & Grants Billing config - BU billing operations, confirm with BU",
}


ROOT_TABLE = "AWARD"


def rel_type(name, fk_fields, child_table, parent_pk, is_collection, counts,
             parent_count, parent_is_root=True):
    if is_collection:
        return "ONE_TO_MANY"
    # A child pointing back up at AWARD is an inverse navigation handle, not a
    # relationship of its own. Label it so it is not mistaken for an extension.
    if not parent_is_root and child_table == ROOT_TABLE:
        return "MANY_TO_ONE_INVERSE"
    # A reference whose foreign key is the parent's own PK, and whose child table
    # has the same row count, is a genuine 1:1 extension rather than a lookup.
    if fk_fields == [parent_pk] and child_table and counts.get(child_table):
        if abs(counts[child_table] - parent_count) / max(parent_count, 1) < 0.05:
            return "ONE_TO_ONE"
    return "MANY_TO_ONE"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--row-counts", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    kfd = _load_parsers()
    root = Path(args.source).expanduser()
    ojb_map, ojb_refs = kfd.parse_ojb(root)
    jpa_map, _ = kfd.parse_jpa(root)

    merged = {}
    for mapping in (ojb_map, jpa_map):
        for cls, meta in mapping.items():
            merged.setdefault(cls, meta)

    counts = {}
    with open(args.row_counts, encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            try:
                counts[r["TABLE_NAME"]] = int(r["ACTUAL_ROWS"] or 0)
            except ValueError:
                pass

    # Re-parse OJB keeping collection descriptors, which parse_ojb drops.
    collections = defaultdict(dict)
    import xml.etree.ElementTree as ET
    for path in root.rglob("*.xml"):
        if "repository" not in path.name.lower():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if "<class-descriptor" not in text:
            continue
        text = re.sub(r"<!DOCTYPE[^>]*(\[[^\]]*\])?>", "", text, flags=re.S)
        try:
            tree = ET.fromstring(text)
        except ET.ParseError:
            continue
        for cd in tree.iter("class-descriptor"):
            cls = cd.get("class")
            if not cls:
                continue
            for c in cd.findall("collection-descriptor"):
                nm = c.get("name")
                el = c.get("element-class-ref")
                if not nm or not el:
                    continue
                collections[cls][nm] = {
                    "child": el,
                    "fk": [f.get("field-ref") for f in c.findall("inverse-foreignkey")
                           if f.get("field-ref")],
                }

    root_table = merged.get(ROOT_CLASS, {}).get("table", "AWARD")
    root_count = counts.get(root_table, 0)
    parent_pk = "awardId"

    rows = []
    seen = set()

    def add_edges(parent_cls, depth):
        parent_table = merged.get(parent_cls, {}).get("table", "")
        parent_simple = parent_cls.split(".")[-1]

        for name, meta in sorted(ojb_refs.get(parent_cls, {}).items()):
            child_cls = meta["class_ref"]
            child_table = merged.get(child_cls, {}).get("table", "")
            key = (parent_cls, name, child_cls)
            if key in seen:
                continue
            seen.add(key)
            fks = [f for f in meta["fk_fields"] if f]
            rtype = rel_type(name, fks, child_table, parent_pk,
                             False, counts, root_count,
                             parent_is_root=(parent_cls == ROOT_CLASS))
            rows.append({
                "PARENT_OBJECT": parent_simple,
                "RELATIONSHIP_NAME": name,
                "RELATIONSHIP_TYPE": rtype,
                "CHILD_OBJECT": child_cls.split(".")[-1],
                "PARENT_TABLE": parent_table,
                "CHILD_TABLE": child_table,
                "JOIN_COLUMNS": ",".join(fks) or "(not declared)",
                "BUSINESS_PURPOSE": PURPOSE.get(name, child_cls.split(".")[-1]),
                "HURON_EXPOSE": "N" if (name in EXCLUDE
                                        or rtype == "MANY_TO_ONE_INVERSE") else "Y",
                "NOTES": (EXCLUDE.get(name, "")
                          or ("inverse navigation back to the Award root; the child "
                              "dataset already carries award_id/award_number"
                              if rtype == "MANY_TO_ONE_INVERSE" else ""))
                         + (f" | child rows: {counts[child_table]:,}"
                            if child_table in counts else ""),
                "_depth": depth,
            })

        for name, meta in sorted(collections.get(parent_cls, {}).items()):
            child_cls = meta["child"]
            child_table = merged.get(child_cls, {}).get("table", "")
            key = (parent_cls, name, child_cls)
            if key in seen:
                continue
            seen.add(key)
            rows.append({
                "PARENT_OBJECT": parent_simple,
                "RELATIONSHIP_NAME": name,
                "RELATIONSHIP_TYPE": "ONE_TO_MANY",
                "CHILD_OBJECT": child_cls.split(".")[-1],
                "PARENT_TABLE": parent_table,
                "CHILD_TABLE": child_table,
                "JOIN_COLUMNS": ",".join(meta["fk"]) or "(not declared)",
                "BUSINESS_PURPOSE": PURPOSE.get(name, child_cls.split(".")[-1]),
                "HURON_EXPOSE": "N" if name in EXCLUDE else "Y",
                "NOTES": EXCLUDE.get(name, "")
                         + (f" | child rows: {counts[child_table]:,}"
                            if child_table in counts else ""),
                "_depth": depth,
            })
            # expand one level below the collection so person->units etc. appear
            if depth == 0 and child_cls in collections and name not in EXCLUDE:
                add_edges(child_cls, depth + 1)

    add_edges(ROOT_CLASS, 0)

    # AwardHierarchy is not declared as a collection on Award: KC navigates it
    # through AwardHierarchyService. It associates on AWARD_NUMBER (not AWARD_ID),
    # so it is version-independent. Added explicitly rather than inferred.
    hier_table = merged.get(
        "org.kuali.kra.award.awardhierarchy.AwardHierarchy", {}).get("table", "AWARD_HIERARCHY")
    rows.append({
        "PARENT_OBJECT": "Award",
        "RELATIONSHIP_NAME": "awardHierarchy",
        "RELATIONSHIP_TYPE": "ONE_TO_MANY",
        "CHILD_OBJECT": "AwardHierarchy",
        "PARENT_TABLE": root_table,
        "CHILD_TABLE": hier_table,
        "JOIN_COLUMNS": "awardNumber",
        "BUSINESS_PURPOSE": "Parent/child award hierarchy (root, parent, originating award)",
        "HURON_EXPOSE": "Y",
        "NOTES": "associates on AWARD_NUMBER, not AWARD_ID - version independent"
                 + (f" | child rows: {counts[hier_table]:,}" if hier_table in counts else ""),
        "_depth": 0,
    })

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    fields = ["PARENT_OBJECT", "RELATIONSHIP_NAME", "RELATIONSHIP_TYPE", "CHILD_OBJECT",
              "PARENT_TABLE", "CHILD_TABLE", "JOIN_COLUMNS", "BUSINESS_PURPOSE",
              "HURON_EXPOSE", "NOTES"]
    rows.sort(key=lambda r: (r["_depth"], r["RELATIONSHIP_TYPE"], r["RELATIONSHIP_NAME"]))
    with out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for r in rows:
            r.pop("_depth", None)
            w.writerow(r)

    from collections import Counter
    print(f"edges: {len(rows)} -> {out}")
    print("by type   :", dict(Counter(r["RELATIONSHIP_TYPE"] for r in rows)))
    print("expose    :", dict(Counter(r["HURON_EXPOSE"] for r in rows)))
    missing = [r for r in rows if not r["CHILD_TABLE"]]
    if missing:
        print(f"unresolved child tables: {len(missing)}")
        for r in missing[:10]:
            print(f"   {r['RELATIONSHIP_NAME']} -> {r['CHILD_OBJECT']}")


if __name__ == "__main__":
    main()
