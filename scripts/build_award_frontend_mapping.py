#!/usr/bin/env python3
"""
Trace every Award field a BU user can see or interact with back to its Java property
and its physical Oracle storage.

The Award UI is Struts/JSP with Kuali tag libraries. Its structure is declared, not
inferred:

  WEB-INF/jsp/award/*.jsp          -> UI_SECTION  (the Award screen)
  WEB-INF/tags/award/*.tag         -> UI_PANEL    (the panel/tab implementation)
  <kul:tab tabTitle="...">         -> UI_TAB      (the visible tab title)
  property="document.awardList[0].x" -> JAVA_PROPERTY
  attributeEntry="${xAttributes.y}"  -> the DataDictionary entry that supplies the
                                        label; authoritative, so it is preferred over
                                        inferring the class from the property path

Labels, DB tables/columns and lookups are then resolved from KUALI_FIELD_DICTIONARY.csv
(itself built from OJB/JPA + DataDictionary). Nothing is guessed: a field with no
resolvable label keeps UI_FIELD_NAME empty, and a field with no physical column is
recorded as DERIVED_DISPLAY rather than given an invented one.

BU custom attributes are added from production configuration, because BU's custom
fields are defined in the database, not in the source.
"""

import argparse
import csv
import re
from collections import defaultdict
from pathlib import Path

# <c:set var="awardExtensionAttributes" value="${DataDictionary.AwardExtension.attributes}"/>
RE_DD_VAR = re.compile(
    r'<c:set\s+var="(\w+)"\s+value="\$\{DataDictionary\.(\w+)\.attributes\}"', re.I)
RE_TAB = re.compile(r'tabTitle="([^"]+)"')
RE_PROPERTY = re.compile(r'property="([^"]+)"')
RE_ATTR_ENTRY = re.compile(r'attributeEntry="\$\{(\w+)\.([\w.]+)\}"')
# e.g. costShareFormHelper.newAwardCostShare.commitmentAmount
#      awardReportsBean.newAwardReportTerms[0].reportCode
RE_NEW_BEAN = re.compile(r"^(\w+)\.new(\w+?)(?:\[[^\]]*\])?\.(.+)$")

# "newXxx" bean property -> the Award collection it belongs to
NEW_BEAN_COLLECTION = {
    "AwardCostShare": "awardCostShares",
    "AwardPaymentSchedule": "paymentScheduleItems",
    "AwardReportTerms": "awardReportTermItems",
    "ProjectPerson": "projectPersons",
    "ApprovedForeignTravel": "approvedForeignTravelTrips",
    "AwardApprovedEquipment": "approvedEquipmentItems",
    "AwardDirectFandADistribution": "awardDirectFandADistributions",
    "Attachment": "awardAttachments",
    "AwardCfda": "awardCfdas",
    "AwardComment": "awardComments",
    "AwardFandaRate": "awardFandaRate",
    "AwardSponsorTerm": "awardSponsorTerms",
    "AwardUnitContact": "awardUnitContacts",
    "AwardApprovedSubaward": "awardApprovedSubawards",
    "AwardBudgetLimit": "awardBudgetLimits",
}

# Struts form beans that front an Award collection panel. The bean's properties
# mirror the business object it edits, so map the prefix to that object rather than
# leaving the whole panel unmapped.
FORM_BEAN_ENTRY = [
    ("projectPersonnelBean.projectPersonnel", "AwardPerson"),
    ("projectPersonnelBean.newAwardContact", "AwardPerson"),
    ("projectPersonnelBean.newProjectPerson", "AwardPerson"),
    ("projectPersonnelBean", "AwardPerson"),
    ("costShareFormHelper.awardCostShares", "AwardCostShare"),
    ("costShareFormHelper", "AwardCostShare"),
    ("awardReportsBean.awardReportTerms", "AwardReportTerm"),
    ("awardReportsBean", "AwardReportTerm"),
    ("paymentScheduleBean", "AwardPaymentSchedule"),
    ("approvedEquipmentBean", "AwardApprovedEquipment"),
    ("approvedForeignTravelBean", "AwardApprovedForeignTravel"),
    ("awardDirectFandADistributionBean", "AwardDirectFandADistribution"),
    ("awardAttachmentFormBean", "AwardAttachment"),
    ("awardCommentBean", "AwardComment"),
    ("awardHierarchyBean", "AwardHierarchy"),
]

# Nested objects rendered on an Award panel but stored elsewhere.
NESTED_DISPLAY = ("person.", "rolodex.", "unit.", "sponsor.", "organization.",
                  "awardStatus.", "awardType.", "activityType.")

RE_READONLY = re.compile(r'readOnly="true"|readOnlyAlternateDisplay', re.I)

# Property-path prefix -> the business object it addresses. Longest match wins.
PATH_TO_ENTRY = [
    ("document.awardList[0].extension.", "AwardExtension"),
    ("document.awardList[0].awardCurrentActionComments.", "AwardComment"),
    ("document.awardList[0].projectPersons", "AwardPerson"),
    ("document.awardList[0].awardAmountInfos", "AwardAmountInfo"),
    ("document.awardList[0].awardCostShares", "AwardCostShare"),
    ("document.awardList[0].awardFandaRate", "AwardFandaRate"),
    ("document.awardList[0].awardReportTermItems", "AwardReportTerm"),
    ("document.awardList[0].awardSponsorTerms", "AwardSponsorTerm"),
    ("document.awardList[0].specialReviews", "AwardSpecialReview"),
    ("document.awardList[0].awardCustomDataList", "AwardCustomData"),
    ("document.awardList[0].fundingProposals", "AwardFundingProposal"),
    ("document.awardList[0].awardUnitContacts", "AwardUnitContact"),
    ("document.awardList[0].sponsorContacts", "AwardSponsorContact"),
    ("document.awardList[0].awardComments", "AwardComment"),
    ("document.awardList[0].awardAttachments", "AwardAttachment"),
    ("document.awardList[0].awardCloseoutItems", "AwardCloseout"),
    ("document.awardList[0].awardCfdas", "AwardCfda"),
    ("document.awardList[0].awardApprovedSubawards", "AwardApprovedSubaward"),
    ("document.awardList[0].awardBudgetLimits", "AwardBudgetLimit"),
    ("document.awardList[0].awardDirectFandADistributions", "AwardDirectFandADistribution"),
    ("document.awardList[0].paymentScheduleItems", "AwardPaymentSchedule"),
    ("document.awardList[0].approvedEquipmentItems", "AwardApprovedEquipment"),
    ("document.awardList[0].approvedForeignTravelTrips", "AwardApprovedForeignTravel"),
    ("document.awardList[0].keywords", "AwardScienceKeyword"),
    ("document.awardList[0].", "Award"),
    ("awardHierarchy", "AwardHierarchy"),
]

# DD entry -> Java class, for entries the dictionary knows by class name.
TECHNICAL_PROPS = {
    "versionNumber", "objectId", "updateUser", "updateTimestamp",
    "newCollectionRecord", "extension.versionNumber", "extension.objectId",
}


def clean_leaf(leaf):
    """Strip EL expressions and collection indexes left in a property path."""
    leaf = re.sub(r"\$\{[^}]*\}", "", leaf)
    leaf = re.sub(r"\[[^\]]*\]", "", leaf)
    return leaf.strip(". ")


def entry_for_path(prop_path):
    for prefix, entry in PATH_TO_ENTRY:
        if prop_path.startswith(prefix):
            leaf = prop_path[len(prefix):]
            # strip collection indexes: projectPersons[0].fullName -> fullName
            return entry, clean_leaf(leaf)
    return None, prop_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--dictionary", required=True)
    ap.add_argument("--custom-attributes", required=True)
    ap.add_argument("--prod-columns", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    root = Path(args.source).expanduser()
    webapp = root / "coeus-webapp/src/main/webapp/WEB-INF"
    tagdir = webapp / "tags/award"
    jspdir = webapp / "jsp/award"

    # ---- field dictionary, keyed by (java simple class, property) and by table.column
    by_class_prop = {}
    for r in csv.DictReader(open(args.dictionary, encoding="utf-8")):
        if r["JAVA_OBJECT"] and r["JAVA_PROPERTY"]:
            by_class_prop.setdefault(
                (r["JAVA_OBJECT"].split(".")[-1], r["JAVA_PROPERTY"]), r)

    # ---- production columns for verification
    prod = defaultdict(set)
    for r in csv.DictReader(open(args.prod_columns, encoding="utf-8")):
        prod[r["TABLE_NAME"]].add(r["COLUMN_NAME"])

    # ---- which JSP (section) includes which tag (panel)
    tag_to_section = {}
    for jsp in sorted(jspdir.glob("*.jsp")):
        text = jsp.read_text(encoding="utf-8", errors="replace")
        section = re.sub(r"(?<!^)(?=[A-Z])", " ", jsp.stem).strip()
        # The Award taglib prefix is kra-a:, not award: -- accept any prefix so the
        # panel/section link does not depend on one project's naming convention.
        for m in re.finditer(r"<[A-Za-z0-9-]+:(\w+)", text):
            tag_to_section.setdefault(m.group(1), section)

    # Panels frequently include other panels. Resolve those transitively so a nested
    # tag inherits the screen its parent appears on instead of reading "not
    # referenced by a JSP".
    tag_names = {t.stem for t in tagdir.glob("*.tag")}
    for _ in range(6):
        changed = False
        for t in sorted(tagdir.glob("*.tag")):
            if t.stem not in tag_to_section:
                continue
            body = t.read_text(encoding="utf-8", errors="replace")
            for m in re.finditer(r"<[A-Za-z0-9-]+:(\w+)", body):
                child = m.group(1)
                if child in tag_names and child not in tag_to_section:
                    tag_to_section[child] = tag_to_section[t.stem]
                    changed = True
        if not changed:
            break

    rows = []
    seen = set()

    for tag in sorted(tagdir.glob("*.tag")):
        text = tag.read_text(encoding="utf-8", errors="replace")
        dd_vars = {m.group(1): m.group(2) for m in RE_DD_VAR.finditer(text)}
        panel = re.sub(r"(?<!^)(?=[A-Z])", " ", tag.stem).strip()
        section = tag_to_section.get(tag.stem, "Award (panel not referenced by a JSP)")

        current_tab = ""
        for line_no, line in enumerate(text.split("\n"), 1):
            mt = RE_TAB.search(line)
            if mt:
                current_tab = mt.group(1)

            for mp in RE_PROPERTY.finditer(line):
                prop_path = mp.group(1)
                # EL indirections used throughout the Award tags
                prop_path = (prop_path
                             .replace("${docAward}", "document.awardList[0]")
                             .replace("${cgbPath}", "document.awardList[0]")
                             .replace("${awardPath}", "document.awardList[0]"))
                # "Add new row" form beans address the same business object as the
                # collection they feed, e.g. costShareFormHelper.newAwardCostShare.<x>
                mb = RE_NEW_BEAN.match(prop_path)
                if mb:
                    prop_path = ("document.awardList[0]." + NEW_BEAN_COLLECTION.get(
                        mb.group(2), mb.group(2)) + "[0]." + mb.group(3))
                nested_display = any(n in prop_path for n in NESTED_DISPLAY)
                if not prop_path.startswith(("document.awardList", "awardHierarchy")):
                    hit = next((e for pfx, e in FORM_BEAN_ENTRY
                                if prop_path.startswith(pfx)), None)
                    if not hit:
                        continue
                    leaf = prop_path.split(".")[-1]
                    leaf = re.sub(r"\[[^\]]*\]", "", leaf)
                    prop_path = f"__bean__{hit}.{leaf}"

                if prop_path.startswith("__bean__"):
                    entry, leaf = prop_path[len("__bean__"):].split(".", 1)
                else:
                    entry, leaf = entry_for_path(prop_path)
                leaf = clean_leaf(leaf)
                if not entry or not leaf or leaf.startswith("methodToCall"):
                    continue

                # attributeEntry, when present, names the DD entry authoritatively
                ma = RE_ATTR_ENTRY.search(line)
                if ma and ma.group(1) in dd_vars:
                    entry = dd_vars[ma.group(1)]
                    leaf = ma.group(2).split(".")[-1] or leaf

                key = (section, panel, current_tab, entry, leaf)
                if key in seen:
                    continue
                seen.add(key)

                d = by_class_prop.get((entry, leaf))
                notes = []

                if d:
                    table, column = d["DB_TABLE"], d["DB_COLUMN"]
                    ui_name = d["UI_FIELD_NAME"]
                    desc = d["FIELD_DESCRIPTION"]
                    dtype = d["DATA_TYPE"]
                    lookup_t, lookup_c = d["LOOKUP_TABLE"], d["LOOKUP_COLUMN"]
                    origin = d["FIELD_ORIGIN"]
                    java_obj = d["JAVA_OBJECT"]
                else:
                    table = column = ui_name = desc = dtype = lookup_t = lookup_c = ""
                    java_obj = entry
                    origin = "DERIVED_DISPLAY"
                    notes.append(
                        "no ORM mapping for this property - rendered from a related "
                        "object or computed in Java/KRAD, not stored in its own column")

                if leaf in TECHNICAL_PROPS:
                    origin = "TECHNICAL"
                if nested_display and not table:
                    origin = "DERIVED_DISPLAY"
                    notes.append("rendered from a related object (person/rolodex/unit/"
                                 "sponsor), not stored on the Award record itself")

                verified = None
                if table:
                    verified = column in prod.get(table, set())
                    if not verified:
                        notes.append("column not found in KCOEUS production")

                if not ui_name:
                    notes.append("no DataDictionary label in source; UI name not asserted")

                if origin == "DERIVED_DISPLAY":
                    confidence = "MEDIUM" if ui_name else "LOW"
                elif verified and ui_name:
                    confidence = "HIGH"
                elif verified:
                    confidence = "MEDIUM"
                else:
                    confidence = "LOW"

                rows.append({
                    "UI_SECTION": section,
                    "UI_TAB": current_tab,
                    "UI_PANEL": panel,
                    "UI_FIELD_NAME": ui_name,
                    "UI_SHORT_LABEL": "",
                    "FIELD_DESCRIPTION": desc,
                    "JAVA_CLASS": java_obj,
                    "JAVA_PROPERTY": leaf,
                    "DB_TABLE": table,
                    "DB_COLUMN": column,
                    "DATA_TYPE": dtype,
                    "LOOKUP_TABLE": lookup_t,
                    "LOOKUP_COLUMN": lookup_c,
                    "LOOKUP_DESCRIPTION_COLUMN": "DESCRIPTION" if lookup_t else "",
                    "FIELD_ORIGIN": origin,
                    "CUSTOM_ATTRIBUTE_ID": "",
                    "REQUIRED": "",
                    "READ_ONLY": "Y" if RE_READONLY.search(line) else "",
                    "CONFIDENCE": confidence,
                    "SOURCE_FILE": str(tag.relative_to(root)),
                    "NOTES": "; ".join(notes),
                })

    # ---- Award personnel ------------------------------------------------
    # The personnel panels address their data through Struts form beans and JSTL
    # macros (${personCreditSplitMacro}.credit, ${projectPersonProperty}.fullName),
    # which cannot be resolved by static text matching. Each entry below was traced
    # by hand from the tag file named in SOURCE_FILE plus the OJB descriptors for
    # AwardPerson / AwardPersonUnit / AwardPersonCreditSplit, and the label is still
    # resolved from the DataDictionary -- never typed in here.
    PERSONNEL = [
        # (tag file, tab, java class, java property, origin override, note)
        ("awardProjectPersonnel.tag", "Key Personnel", "AwardPerson", "personId",
         None, "KIM person selected on the Key Personnel panel"),
        ("awardProjectPersonnel.tag", "Key Personnel", "AwardPerson", "rolodexId",
         None, "external contact alternative to a KIM person"),
        ("awardProjectPersonnel.tag", "Key Personnel", "AwardPerson", "fullName",
         None, "persisted denormalized copy; AwardContact.getFullName() refreshes it "
               "from the person record on read"),
        ("awardProjectPersonnel.tag", "Key Personnel", "AwardPerson", "roleCode",
         None, "UI form bean calls this contactRoleCode; decodes against "
               "EPS_PROP_PERSON_ROLE, which holds 2 rows per code (DEFAULT and "
               "'NIH Multiple PI') - an unfiltered join doubles the dataset"),
        ("awardProjectPersonnel.tag", "Key Personnel", "AwardPerson", "keyPersonRole",
         None, ""),
        ("awardProjectPersonnel.tag", "Key Personnel", "AwardPerson", "person",
         "DERIVED_DISPLAY", "KcPerson resolved in Java by KcPersonService from "
               "PERSON_ID; no ORM relationship from AWARD_PERSONS to a person table"),
        ("awardProjectPersonnel.tag", "Key Personnel", "AwardPerson", "rolodex",
         "DERIVED_DISPLAY", "NonOrganizationalRolodex resolved from ROLODEX_ID; "
               "joinable to ROLODEX"),
        ("awardProjectPersonnelPersonDetails.tag", "Person Details", "AwardPerson",
         "academicYearEffort", None, ""),
        ("awardProjectPersonnelPersonDetails.tag", "Person Details", "AwardPerson",
         "calendarYearEffort", None, ""),
        ("awardProjectPersonnelPersonDetails.tag", "Person Details", "AwardPerson",
         "summerEffort", None, ""),
        ("awardProjectPersonnelPersonDetails.tag", "Person Details", "AwardPerson",
         "totalEffort", None, ""),
        ("awardProjectPersonnelPersonDetails.tag", "Person Details", "AwardPerson",
         "faculty", None, "stored as FACULTY_FLAG"),
        ("awardProjectPersonnelPersonDetails.tag", "Person Details", "AwardPerson",
         "includeInCreditAllocation", None, "stored as ADD_CREDIT_SPLIT"),
        ("awardProjectPersonnelPersonDetails.tag", "Person Details", "AwardPerson",
         "optInUnitStatus", None, ""),
        ("awardProjectPersonnelUnits.tag", "Unit Details", "AwardPersonUnit",
         "unitNumber", None, ""),
        ("awardProjectPersonnelUnits.tag", "Unit Details", "AwardPersonUnit",
         "leadUnit", None, "stored as LEAD_UNIT_FLAG"),
        ("awardProjectPersonnelUnits.tag", "Unit Details", "AwardPersonUnit",
         "unit", "DERIVED_DISPLAY", "unit name shown from UNIT.UNIT_NAME via "
               "UNIT_NUMBER; not stored on AWARD_PERSON_UNITS"),
        ("creditSplit.tag", "Key Personnel and Credit Split", "AwardPersonCreditSplit",
         "credit", None, "person-level credit percentage; the UI renders one column "
               "per INV_CREDIT_TYPE"),
        ("creditSplit.tag", "Key Personnel and Credit Split", "AwardPersonCreditSplit",
         "invCreditTypeCode", None, "decodes against INV_CREDIT_TYPE"),
        ("creditSplit.tag", "Key Personnel and Credit Split",
         "AwardPersonUnitCreditSplit", "credit", None,
         "unit-level credit percentage"),
        ("creditSplit.tag", "Key Personnel and Credit Split",
         "AwardPersonUnitCreditSplit", "invCreditTypeCode", None,
         "decodes against INV_CREDIT_TYPE"),
    ]

    for tagfile, tab, cls, prop, origin_override, note in PERSONNEL:
        d = by_class_prop.get((cls, prop))
        table = d["DB_TABLE"] if d else ""
        column = d["DB_COLUMN"] if d else ""
        ui_name = d["UI_FIELD_NAME"] if d else ""
        origin = origin_override or (d["FIELD_ORIGIN"] if d else "DERIVED_DISPLAY")
        notes = [note] if note else []
        if not table:
            notes.append("no physical column - value assembled in Java/KRAD")
        if not ui_name:
            notes.append("no DataDictionary label in source; UI name not asserted")
        verified = column in prod.get(table, set()) if table else False
        rows.append({
            "UI_SECTION": "Award Contacts",
            "UI_TAB": tab,
            "UI_PANEL": re.sub(r"(?<!^)(?=[A-Z])", " ", tagfile[:-4]).strip(),
            "UI_FIELD_NAME": ui_name,
            "UI_SHORT_LABEL": "",
            "FIELD_DESCRIPTION": d["FIELD_DESCRIPTION"] if d else "",
            "JAVA_CLASS": d["JAVA_OBJECT"] if d else cls,
            "JAVA_PROPERTY": prop,
            "DB_TABLE": table,
            "DB_COLUMN": column,
            "DATA_TYPE": d["DATA_TYPE"] if d else "",
            "LOOKUP_TABLE": d["LOOKUP_TABLE"] if d else "",
            "LOOKUP_COLUMN": d["LOOKUP_COLUMN"] if d else "",
            "LOOKUP_DESCRIPTION_COLUMN": "DESCRIPTION" if (d and d["LOOKUP_TABLE"]) else "",
            "FIELD_ORIGIN": origin,
            "CUSTOM_ATTRIBUTE_ID": "",
            "REQUIRED": "",
            "READ_ONLY": "",
            "CONFIDENCE": "HIGH" if (verified and ui_name) else
                          ("MEDIUM" if (verified or ui_name) else "LOW"),
            "SOURCE_FILE": f"coeus-webapp/src/main/webapp/WEB-INF/tags/award/{tagfile}",
            "NOTES": "; ".join(n for n in notes if n),
        })

    # ---- BU custom attributes: defined in the database, not the source ----
    for ca in csv.DictReader(open(args.custom_attributes, encoding="utf-8")):
        if (ca.get("DOCUMENT_TYPE_CODE") or "").strip() != "AWRD":
            continue
        rows.append({
            "UI_SECTION": "Award Custom Data",
            "UI_TAB": ca.get("GROUP_NAME", ""),
            "UI_PANEL": "award Custom Data",
            "UI_FIELD_NAME": ca.get("ATTRIBUTE_LABEL", ""),
            "UI_SHORT_LABEL": ca.get("ATTRIBUTE_NAME", ""),
            "FIELD_DESCRIPTION": ca.get("ATTRIBUTE_NAME", ""),
            "JAVA_CLASS": "org.kuali.kra.award.customdata.AwardCustomData",
            "JAVA_PROPERTY": "value",
            "DB_TABLE": "AWARD_CUSTOM_DATA",
            "DB_COLUMN": "VALUE",
            "DATA_TYPE": ca.get("DATA_TYPE_DESC") or ca.get("DATA_TYPE_CODE", ""),
            "LOOKUP_TABLE": "CUSTOM_ATTRIBUTE",
            "LOOKUP_COLUMN": "ID",
            "LOOKUP_DESCRIPTION_COLUMN": "LABEL",
            "FIELD_ORIGIN": "BU_CUSTOM_ATTRIBUTE",
            "CUSTOM_ATTRIBUTE_ID": ca.get("CUSTOM_ATTRIBUTE_ID", ""),
            "REQUIRED": "Y" if (ca.get("IS_REQUIRED") or "").strip() == "Y" else "",
            "READ_ONLY": "",
            "CONFIDENCE": "HIGH",
            "SOURCE_FILE": "KCOEUS.CUSTOM_ATTRIBUTE + CUSTOM_ATTRIBUTE_DOCUMENT (production)",
            "NOTES": "logical field is CUSTOM_ATTRIBUTE_ID "
                     f"{ca.get('CUSTOM_ATTRIBUTE_ID')}; VALUE is generic EAV storage, "
                     "not the field name",
        })

    # ---- dedupe -----------------------------------------------------------
    # The generic tag scan and the explicit personnel block can describe the same
    # field, and the scan sometimes reaches a property through a mis-parsed bean
    # path. Collapse to one row per (screen, panel, tab, field), preferring the row
    # that carries a resolved label and a real column.
    CONF = {"HIGH": 3, "MEDIUM": 2, "LOW": 1}
    best = {}
    for r in rows:
        leaf = r["JAVA_PROPERTY"].split(".")[-1]
        # BU custom attributes all share AWARD_CUSTOM_DATA.VALUE -- their identity is
        # the CUSTOM_ATTRIBUTE_ID, not the physical column.
        if r["CUSTOM_ATTRIBUTE_ID"]:
            ident = ("CUSTOM_ATTRIBUTE", r["CUSTOM_ATTRIBUTE_ID"])
        elif r["DB_COLUMN"]:
            ident = (r["DB_TABLE"], r["DB_COLUMN"])
        else:
            ident = ("", leaf)
        key = (r["UI_SECTION"], r["UI_PANEL"], r["UI_TAB"]) + ident
        score = (1 if r["UI_FIELD_NAME"] else 0,
                 1 if r["DB_COLUMN"] else 0,
                 CONF.get(r["CONFIDENCE"], 0),
                 1 if "." not in r["JAVA_PROPERTY"] else 0,
                 len(r["NOTES"]))
        if key not in best or score > best[key][0]:
            best[key] = (score, r)
    rows = [r for _s, r in best.values()]

    fields = ["UI_SECTION", "UI_TAB", "UI_PANEL", "UI_FIELD_NAME", "UI_SHORT_LABEL",
              "FIELD_DESCRIPTION", "JAVA_CLASS", "JAVA_PROPERTY", "DB_TABLE", "DB_COLUMN",
              "DATA_TYPE", "LOOKUP_TABLE", "LOOKUP_COLUMN", "LOOKUP_DESCRIPTION_COLUMN",
              "FIELD_ORIGIN", "CUSTOM_ATTRIBUTE_ID", "REQUIRED", "READ_ONLY",
              "CONFIDENCE", "SOURCE_FILE", "NOTES"]
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    rows.sort(key=lambda r: (r["UI_SECTION"], r["UI_PANEL"], r["UI_TAB"],
                             r["UI_FIELD_NAME"] or r["JAVA_PROPERTY"]))
    with out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    from collections import Counter
    print(f"Award UI fields discovered : {len(rows)} -> {out}")
    print("FIELD_ORIGIN :", dict(Counter(r["FIELD_ORIGIN"] for r in rows)))
    print("CONFIDENCE   :", dict(Counter(r["CONFIDENCE"] for r in rows)))
    print(f"mapped to a DB column      : {sum(1 for r in rows if r['DB_COLUMN'])}")
    print(f"mapped through a lookup    : {sum(1 for r in rows if r['LOOKUP_TABLE'])}")
    print(f"with a UI label            : {sum(1 for r in rows if r['UI_FIELD_NAME'])}")
    print(f"UI sections                : {len({r['UI_SECTION'] for r in rows})}")
    print(f"UI panels                  : {len({r['UI_PANEL'] for r in rows})}")


if __name__ == "__main__":
    main()
