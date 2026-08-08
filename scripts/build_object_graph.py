#!/usr/bin/env python3
"""
Derive a KC business-object graph from the Kuali source, not from table names.

Generalises the Award graph builder to any KC root object. Starts at the configured
root class and walks the OJB/JPA relationship model:

  reference-descriptor   -> MANY_TO_ONE, or ONE_TO_ONE when the foreign key is the
                            parent's own primary key and the child table has a
                            matching row count, or MANY_TO_ONE_INVERSE when a child
                            points back up at the root
  collection-descriptor  -> ONE_TO_MANY

Each edge is resolved to real KCOEUS tables and annotated with the production row
count, so the graph reflects what BU actually holds rather than what KC supports.

Relationships KC navigates through a service rather than an ORM collection (Award's
hierarchy, a proposal's originating development proposal) are declared per module in
EXTRA_EDGES so they are documented explicitly instead of being missed.

Usage:
  build_object_graph.py --module award    --source ... --row-counts ... --output ...
  build_object_graph.py --module proposal --source ... --row-counts ... --output ...
"""

import argparse
import csv
import importlib.util
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
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


# Reference tables are small and code-defining; a large transaction table can also be
# a foreign-key target without being a lookup.
REFERENCE_ROW_CEILING = 20_000

MODULES = {
    "award": {
        "root_class": "org.kuali.kra.award.home.Award",
        "root_table": "AWARD",
        "root_pk_property": "awardId",
        "purpose": {
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
            "syncChanges": "Award hierarchy sync change log",
            "syncStatuses": "Award hierarchy sync status",
            "awardNotifications": "Notification log",
            "awardReportTermRecipients": "Report recipients",
            "units": "Units the person is credited under",
            "creditSplits": "Credit split percentages",
            "unitCreditSplits": "Unit-level credit split percentages",
        },
        "exclude": {
            "awardDocument": "KEW workflow routing header - platform infrastructure, not Grants data",
            "versionHistory": "framework versioning bookkeeping, not a business relationship",
            "syncChanges": "hierarchy sync change log - operational, not conversion data",
            "syncStatuses": "hierarchy sync status - operational, not conversion data",
            "awardNotifications": "notification send log - operational",
            "awardTemplate": "authoring template the record was created from, not award content",
            "allFundingProposals": "duplicate of fundingProposals without an inverse FK",
            "awardCgbList": "EXCLUDED on evidence, not name: stock Kuali child collection "
                            "with a real UI panel and DataDictionary, but production carries "
                            "no information - 7 of 14 business fields are entirely NULL and "
                            "the other 6 are 'N' on all 154,705 rows (zero variance)",
        },
        "core_entities": {"AWARD"},
        "extra_edges": [{
            "relationship_name": "awardHierarchy",
            "relationship_type": "ONE_TO_MANY",
            "child_object": "AwardHierarchy",
            "child_class": "org.kuali.kra.award.awardhierarchy.AwardHierarchy",
            "join_columns": "awardNumber",
            "business_purpose": "Parent/child award hierarchy (root, parent, originating award)",
            "expose": "Y",
            "notes": "associates on AWARD_NUMBER, not AWARD_ID - version independent; "
                     "not declared as an OJB collection, KC navigates it via "
                     "AwardHierarchyService",
        }],
    },
    "proposal": {
        "root_class": "org.kuali.kra.institutionalproposal.home.InstitutionalProposal",
        "root_table": "PROPOSAL",
        "root_pk_property": "proposalId",
        "purpose": {
            "extension": "BU-specific extended Institutional Proposal attributes",
            "sponsor": "Sponsor of record",
            "primeSponsor": "Prime (pass-through) sponsor",
            "leadUnit": "Owning organizational unit",
            "proposalStatus": "Proposal status decode",
            "proposalType": "Proposal type decode",
            "activityType": "Activity type decode",
            "noticeOfOpportunity": "Notice of opportunity decode",
            "nsfCodeBo": "NSF science code decode",
            "rolodex": "External contact (non-employee) on the proposal",
            "institutionalProposalDocument": "KEW routing document header",
            "projectPersons": "Key personnel on the proposal",
            "institutionalProposalCostShares": "Cost share commitments",
            "institutionalProposalFandAs": "F&A / IDC rates applied",
            "institutionalProposalUnrecoveredFandAs": "Unrecovered F&A by period",
            "institutionalProposalCustomDataList": "BU custom attribute values (EAV)",
            "institutionalProposalUnitContacts": "Unit administrative contacts",
            "institutionalProposalNotepads": "Notepad entries",
            "institutionalProposalScienceKeywords": "Science keywords",
            "specialReviews": "Compliance special reviews (IRB/IACUC/etc.)",
            "proposalComments": "Free-text comments by type",
            "instProposalAttachments": "Attachment metadata",
            "proposalCfdas": "CFDA / ALN numbers",
            "awardFundingProposals": "Awards funded by this proposal",
            "allFundingProposals": "Funding links incl. inactive",
            "proposalIpReviewJoins": "Intellectual property review linkage",
            "units": "Units the person is credited under",
            "creditSplits": "Credit split percentages",
            "unitCreditSplits": "Unit-level credit split percentages",
        },
        "exclude": {
            "institutionalProposalDocument":
                "KEW workflow routing header - platform infrastructure, not Grants data",
            "allFundingProposals":
                "duplicate of awardFundingProposals without an inverse FK",
        },
        "core_entities": {"PROPOSAL"},
        "extra_edges": [],
    },
}


def rel_type(fk_fields, child_table, parent_pk, is_collection, counts,
             parent_count, root_table, parent_is_root):
    if is_collection:
        return "ONE_TO_MANY"
    # A child pointing back up at the root is an inverse navigation handle.
    if not parent_is_root and child_table == root_table:
        return "MANY_TO_ONE_INVERSE"
    # A reference whose FK is the parent's own PK, with a matching row count, is a
    # genuine 1:1 extension rather than a lookup.
    if fk_fields == [parent_pk] and child_table and counts.get(child_table):
        if abs(counts[child_table] - parent_count) / max(parent_count, 1) < 0.10:
            return "ONE_TO_ONE"
    return "MANY_TO_ONE"


def load_collections(root: Path):
    """OJB collection descriptors, which the field-dictionary parser drops."""
    collections = defaultdict(dict)
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
                nm, el = c.get("name"), c.get("element-class-ref")
                if nm and el:
                    collections[cls][nm] = {
                        "child": el,
                        "fk": [f.get("field-ref")
                               for f in c.findall("inverse-foreignkey")
                               if f.get("field-ref")],
                    }
    return collections


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", required=True, choices=sorted(MODULES))
    ap.add_argument("--source", required=True)
    ap.add_argument("--row-counts", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    cfg = MODULES[args.module]
    root_class = cfg["root_class"]
    root_table = cfg["root_table"]
    parent_pk = cfg["root_pk_property"]
    PURPOSE, EXCLUDE = cfg["purpose"], cfg["exclude"]

    kfd = _load_parsers()
    src = Path(args.source).expanduser()
    ojb_map, ojb_refs = kfd.parse_ojb(src)
    jpa_map, _ = kfd.parse_jpa(src)

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

    collections = load_collections(src)
    root_count = counts.get(root_table, 0)

    rows, seen = [], set()

    def child_rows_note(table):
        return f" | child rows: {counts[table]:,}" if table in counts else ""

    def add_edges(parent_cls, depth):
        parent_table = merged.get(parent_cls, {}).get("table", "")
        parent_simple = parent_cls.split(".")[-1]
        is_root = parent_cls == root_class

        for name, meta in sorted(ojb_refs.get(parent_cls, {}).items()):
            child_cls = meta["class_ref"]
            child_table = merged.get(child_cls, {}).get("table", "")
            key = (parent_cls, name, child_cls)
            if key in seen:
                continue
            seen.add(key)
            fks = [f for f in meta["fk_fields"] if f]
            rtype = rel_type(fks, child_table, parent_pk, False, counts,
                             root_count, root_table, is_root)
            inverse = rtype == "MANY_TO_ONE_INVERSE"
            rows.append({
                "PARENT_OBJECT": parent_simple,
                "RELATIONSHIP_NAME": name,
                "RELATIONSHIP_TYPE": rtype,
                "CHILD_OBJECT": child_cls.split(".")[-1],
                "PARENT_TABLE": parent_table,
                "CHILD_TABLE": child_table,
                "JOIN_COLUMNS": ",".join(fks) or "(not declared)",
                "BUSINESS_PURPOSE": PURPOSE.get(name, child_cls.split(".")[-1]),
                "HURON_EXPOSE": "N" if (name in EXCLUDE or inverse) else "Y",
                "NOTES": (EXCLUDE.get(name, "") or
                          ("inverse navigation back to the root; the child dataset "
                           "already carries the root keys" if inverse else ""))
                         + child_rows_note(child_table),
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
                "NOTES": EXCLUDE.get(name, "") + child_rows_note(child_table),
                "_depth": depth,
            })
            if depth == 0 and child_cls in collections and name not in EXCLUDE:
                add_edges(child_cls, depth + 1)

    add_edges(root_class, 0)

    for extra in cfg["extra_edges"]:
        child_table = merged.get(extra["child_class"], {}).get("table", "")
        rows.append({
            "PARENT_OBJECT": root_class.split(".")[-1],
            "RELATIONSHIP_NAME": extra["relationship_name"],
            "RELATIONSHIP_TYPE": extra["relationship_type"],
            "CHILD_OBJECT": extra["child_object"],
            "PARENT_TABLE": root_table,
            "CHILD_TABLE": child_table,
            "JOIN_COLUMNS": extra["join_columns"],
            "BUSINESS_PURPOSE": extra["business_purpose"],
            "HURON_EXPOSE": extra["expose"],
            "NOTES": extra["notes"] + child_rows_note(child_table),
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

    print(f"module    : {args.module}  root {root_class.split('.')[-1]} -> {root_table}")
    print(f"edges     : {len(rows)} -> {out}")
    print("by type   :", dict(Counter(r["RELATIONSHIP_TYPE"] for r in rows)))
    print("expose    :", dict(Counter(r["HURON_EXPOSE"] for r in rows)))
    missing = [r for r in rows if not r["CHILD_TABLE"]]
    if missing:
        print(f"unresolved child tables: {len(missing)}")
        for r in missing[:10]:
            print(f"   {r['RELATIONSHIP_NAME']} -> {r['CHILD_OBJECT']}")


if __name__ == "__main__":
    main()
