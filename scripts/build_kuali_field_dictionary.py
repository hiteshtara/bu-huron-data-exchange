#!/usr/bin/env python3
"""
Build the BU Kuali Research field dictionary for the Huron AI mapping package.

It produces one row per *logical* field, chaining:

    Oracle table/column -> Java object/property -> Kuali UI label
                        -> lookup/reference object -> BU custom attribute
                        -> mapping priority

Sources (all READ ONLY):
  1. OJB ORM  : coeus-impl/**/repository-*.xml
                <class-descriptor class= table=> / <field-descriptor name= column=>
  2. JPA ORM  : *.java with @Table(name="...") / @Column(name="...")
  3. Kuali DataDictionary : Spring bean XML (BusinessObjectEntry + AttributeDefinition).
                <property name="label"/> is what the front end actually renders.
  4. KCOEUS production metadata : ALL_TAB_COLUMNS extract (datatypes, lengths) and
                the CUSTOM_ATTRIBUTE / CUSTOM_ATTRIBUTE_DOCUMENT configuration.

Two rules drive the design:

  * A Java property name is NOT a UI label. UI_FIELD_NAME is populated only when a
    DataDictionary label resolves from source; otherwise it is left EMPTY.

  * BU's custom fields are EAV. The physical column AWARD_CUSTOM_DATA.VALUE is not a
    business field -- the logical field is CUSTOM_ATTRIBUTE_ID + its definition. The
    Java source describes the custom-attribute *mechanism*; BU's database says which
    custom fields BU actually configured. So each configured custom attribute is
    emitted as its own first-class row (FIELD_ORIGIN=BU_CUSTOM_ATTRIBUTE), and module
    applicability comes from CUSTOM_ATTRIBUTE_DOCUMENT, never from the mere presence
    of a value.

Nothing is written to the Kuali source tree; it is only read.
"""

import argparse
import csv
import os
import re
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path

SPRING_NS = "{http://www.springframework.org/schema/beans}"
P_NS = "{http://www.springframework.org/schema/p}"


# --------------------------------------------------------------------------
# 1. OJB repository XML  ->  (java_class, table, property, column)
# --------------------------------------------------------------------------
def parse_ojb(root: Path):
    """Return (mappings, references)."""
    mappings = {}
    references = defaultdict(dict)

    files = [p for p in root.rglob("*.xml") if "repository" in p.name.lower()]

    for path in files:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if "<class-descriptor" not in text:
            continue

        # OJB files carry a DOCTYPE with an external DTD; strip it so ET does not
        # try to resolve it.
        text = re.sub(r"<!DOCTYPE[^>]*(\[[^\]]*\])?>", "", text, flags=re.S)
        try:
            tree = ET.fromstring(text)
        except ET.ParseError:
            continue

        for cd in tree.iter("class-descriptor"):
            java_class = cd.get("class")
            table = cd.get("table")
            if not java_class or not table:
                continue  # interfaces / extents have no table
            entry = mappings.setdefault(
                java_class, {"table": table, "fields": {}, "source": str(path)}
            )
            for fd in cd.findall("field-descriptor"):
                prop, col = fd.get("name"), fd.get("column")
                if not prop or not col:
                    continue
                entry["fields"][prop] = {
                    "column": col,
                    "pk": fd.get("primarykey") == "true",
                    "source": str(path),
                }
            for rd in cd.findall("reference-descriptor"):
                name, class_ref = rd.get("name"), rd.get("class-ref")
                if not name or not class_ref:
                    continue
                references[java_class][name] = {
                    "class_ref": class_ref,
                    "fk_fields": [
                        fk.get("field-ref")
                        for fk in rd.findall("foreignkey")
                        if fk.get("field-ref")
                    ],
                }
    return mappings, dict(references)


# --------------------------------------------------------------------------
# 2. JPA annotations  ->  (java_class, table, property, column)
# --------------------------------------------------------------------------
RE_TABLE = re.compile(r'@Table\s*\(\s*name\s*=\s*"([^"]+)"')
RE_PACKAGE = re.compile(r"^\s*package\s+([\w.]+)\s*;", re.M)
RE_COL_FIELD = re.compile(
    r'@Column\s*\(\s*name\s*=\s*"([^"]+)"[^)]*\)'
    r'(?:\s*@[\w.]+(?:\s*\([^)]*\))?)*'
    r'\s*(?:private|protected|public)\s+[\w.<>,\[\]\s]+?\s+(\w+)\s*[;=]',
    re.S,
)
RE_JOINCOL_FIELD = re.compile(
    r'@JoinColumn\s*\(([^)]*)\)'
    r'(?:\s*@[\w.]+(?:\s*\([^)]*\))?)*'
    r'\s*(?:private|protected|public)\s+([\w.<>,\[\]]+)\s+(\w+)\s*[;=]',
    re.S,
)
RE_ID_COL = re.compile(r'@Id\b[\s\S]{0,200}?@Column\s*\(\s*name\s*=\s*"([^"]+)"')


def parse_jpa(root: Path):
    mappings, references = {}, defaultdict(dict)

    for path in root.rglob("*.java"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if "@Table(name" not in text:
            continue
        m = RE_TABLE.search(text)
        if not m:
            continue
        pkg = RE_PACKAGE.search(text)
        java_class = f"{pkg.group(1)}.{path.stem}" if pkg else path.stem

        pk_cols = set(RE_ID_COL.findall(text))
        fields = {
            prop: {"column": col, "pk": col in pk_cols, "source": str(path)}
            for col, prop in RE_COL_FIELD.findall(text)
        }
        if not fields:
            continue
        mappings[java_class] = {
            "table": m.group(1),
            "fields": fields,
            "source": str(path),
        }
        for args, jtype, prop in RE_JOINCOL_FIELD.findall(text):
            nm = re.search(r'name\s*=\s*"([^"]+)"', args)
            if nm:
                references[java_class][prop] = {"join_column": nm.group(1)}
    return mappings, dict(references)


# --------------------------------------------------------------------------
# 3. Kuali DataDictionary Spring beans -> UI labels
# --------------------------------------------------------------------------
def _bean_props(bean):
    props = {}
    for k, v in bean.attrib.items():
        if k.startswith(P_NS):
            props[k[len(P_NS):]] = v
    for prop in bean.findall(f"{SPRING_NS}property"):
        name = prop.get("name")
        if name is not None and prop.get("value") is not None:
            props[name] = prop.get("value")
    return props


def parse_datadictionary(root: Path):
    beans, bo_entries = {}, {}

    for path in root.rglob("*.xml"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if "springframework.org/schema/beans" not in text:
            continue
        try:
            tree = ET.fromstring(text)
        except ET.ParseError:
            continue

        for bean in tree.iter(f"{SPRING_NS}bean"):
            bid = bean.get("id")
            if not bid:
                continue
            props = _bean_props(bean)
            beans[bid] = {
                "parent": bean.get("parent"),
                "props": props,
                "source": str(path),
            }
            if "businessObjectClass" in props:
                entry = bid[:-len("-parentBean")] if bid.endswith("-parentBean") else bid
                bo_entries.setdefault(
                    entry, {"bo_class": props["businessObjectClass"], "source": str(path)}
                )
    return beans, bo_entries


def resolve_prop(beans, bean_id, key, _depth=0):
    """Resolve a bean property, walking the Spring parent chain (child overrides)."""
    if _depth > 12 or bean_id not in beans:
        return None, None
    b = beans[bean_id]
    if key in b["props"]:
        return b["props"][key], b["source"]
    if b["parent"]:
        return resolve_prop(beans, b["parent"], key, _depth + 1)
    return None, None


def build_attribute_index(beans, bo_entries):
    """(entry, property) -> label/description/maxLength record.

    Kuali resolves AttributeDefinition beans through Spring parent inheritance, and
    that inheritance frequently crosses files (Award-activityTypeCode inherits from
    DevelopmentProposal-activityTypeCode-parentBean). An inherited label is what the
    front end renders, so it counts -- but we record where it was defined.
    """
    index = {}
    for bid, b in beans.items():
        name, _ = resolve_prop(beans, bid, "name")
        if not name:
            continue
        base = bid[:-len("-parentBean")] if bid.endswith("-parentBean") else bid
        if not base.endswith("-" + name):
            continue
        entry = base[: -(len(name) + 1)]
        if entry not in bo_entries:
            continue
        label, lsrc = resolve_prop(beans, bid, "label")
        short, ssrc = resolve_prop(beans, bid, "shortLabel")
        desc, _ = resolve_prop(beans, bid, "description")
        summ, _ = resolve_prop(beans, bid, "summary")
        maxlen, _ = resolve_prop(beans, bid, "maxLength")
        if not any([label, short, desc, summ]):
            continue
        rec = {
            "label": label or "",
            "short_label": short or "",
            "description": desc or "",
            "summary": summ or "",
            "max_length": maxlen or "",
            "source": lsrc or ssrc or b["source"],
            "own_label": "label" in b["props"],
        }
        prev = index.get((entry, name))
        if prev is None or (not prev["label"] and rec["label"]):
            index[(entry, name)] = rec
    return index


# --------------------------------------------------------------------------
# classification
# --------------------------------------------------------------------------
NON_LOOKUP_TABLES = {
    "VERSION_HISTORY", "KREW_DOC_HDR_T", "DOCUMENT_NEXTVALUE", "KRNS_DOC_HDR_T",
}

# Purely technical / framework columns. Real data, but nothing for Huron to map.
TECHNICAL_COLUMNS = {
    "OBJ_ID", "VER_NBR", "VERSION_NUMBER",
    "UPDATE_TIMESTAMP", "UPDATE_USER", "CREATE_TIMESTAMP", "CREATE_USER",
    "LAST_UPDATE_TIMESTAMP", "LAST_UPDATE_USER",
}

# Lineage keys that must survive to Huron so records stay traceable end to end.
LINEAGE_KEYS = {
    "AWARD_ID", "AWARD_NUMBER", "PROPOSAL_ID", "PROPOSAL_NUMBER",
    "INSTITUTIONAL_PROPOSAL_ID", "SUBAWARD_ID", "SUBAWARD_CODE",
    "NEGOTIATION_ID", "NEGOTIATION_NUMBER", "SEQUENCE_NUMBER", "DOCUMENT_NUMBER",
    "SPONSOR_CODE", "PRIME_SPONSOR_CODE", "UNIT_NUMBER", "LEAD_UNIT_NUMBER",
    "ORGANIZATION_ID", "PERSON_ID", "ROLODEX_ID", "CUSTOM_ATTRIBUTE_ID",
    "PROTOCOL_NUMBER", "TRANSACTION_ID",
}

TABLE_MODULE_RULES = [
    ("BU custom fields", re.compile(r"CUSTOM_DATA$|^CUSTOM_ATTRIBUTE|_EXTENSION$")),
    ("Award", re.compile(r"^AWARD|^AWD_|^TIME_AND_MONEY|^PENDING_TRANSACTIONS|^TRANSACTION_DETAILS")),
    ("Institutional Proposal", re.compile(r"^PROPOSAL|^IP_|^INSTITUTE_PROPOSAL")),
    ("Proposal / pre-award", re.compile(r"^EPS_|^BUDGET|^BUD_|^NARRATIVE|^S2S_")),
    ("Subaward", re.compile(r"^SUBAWARD|^SUBCONTRACT")),
    ("Negotiation", re.compile(r"^NEGOTIATION")),
    ("Sponsor", re.compile(r"^SPONSOR")),
    ("Organization", re.compile(r"^ORGANIZATION")),
    ("Unit", re.compile(r"^UNIT")),
]

MODULE_RULES = [
    ("Award", re.compile(r"\.award\.|\.timeandmoney\.|awardbudget", re.I)),
    ("Institutional Proposal", re.compile(r"institutionalproposal", re.I)),
    ("Proposal / pre-award", re.compile(r"propdev|proposaldevelopment|\.budget\.|\.s2s", re.I)),
    ("Subaward", re.compile(r"subaward", re.I)),
    ("Negotiation", re.compile(r"negotiation", re.I)),
    ("Sponsor", re.compile(r"\.sponsor", re.I)),
    ("Organization", re.compile(r"\.org\b|\.organization", re.I)),
    ("Unit", re.compile(r"\.unit", re.I)),
    ("Person / Rolodex", re.compile(r"\.person|rolodex|\.kim\.", re.I)),
]

BUSINESS_MODULES = {
    "Award", "Institutional Proposal", "Proposal / pre-award", "Subaward",
    "Negotiation", "Sponsor", "Organization", "Unit", "BU custom fields",
}

# KC document type codes -> the domain the custom attribute belongs to.
DOC_TYPE_MODULE = {
    "AWRD": "Award",
    "INPR": "Institutional Proposal",
    "PRDV": "Proposal / pre-award",
    "SAWD": "Subaward",
    "NGT": "Negotiation",
    "PROT": "Protocol / IRB (out of Grants scope)",
}

# Which physical EAV table stores values for each document type.
DOC_TYPE_TABLE = {
    "AWRD": "AWARD_CUSTOM_DATA",
    "INPR": "PROPOSAL_CUSTOM_DATA",
    "PRDV": "CUSTOM_ATTRIBUTE_DOC_VALUE",
    "SAWD": "SUBAWARD_CUSTOM_DATA",
    "NGT": "NEGOTIATION_CUSTOM_DATA",
    "PROT": "CUSTOM_ATTRIBUTE_DOC_VALUE",
}

USAGE_COLUMN = {
    "AWRD": "AWARD_VALUE_ROWS",
    "INPR": "PROPOSAL_VALUE_ROWS",
    "SAWD": "SUBAWARD_VALUE_ROWS",
    "NGT": "NEGOTIATION_VALUE_ROWS",
}


def classify_module(java_class, table):
    for mod, rx in TABLE_MODULE_RULES:
        if rx.search(table or ""):
            return mod
    for mod, rx in MODULE_RULES:
        if rx.search(java_class or ""):
            return mod
    return "Reference / lookup"


# Reference tables are small and code-defining. A big transaction table can also be
# a foreign-key target (AWARD_AMOUNT_INFO points at AWARD) without being a lookup, so
# being a FK target is necessary but not sufficient.
REFERENCE_ROW_CEILING = 20_000


# Primary domain entities are never "reference data", however small they are.
CORE_ENTITY_TABLES = {
    "AWARD", "PROPOSAL", "SUBAWARD", "NEGOTIATION", "EPS_PROPOSAL", "BUDGET",
    "PROPOSAL_LOG", "TIME_AND_MONEY_DOCUMENT", "INSTITUTE_PROPOSAL_DOCUMENT",
}


def classify_origin(table, is_lookup_target, row_count):
    if table.endswith("_EXTENSION") or table.startswith("BU_"):
        return "BU_EXTENSION"
    if table in CORE_ENTITY_TABLES:
        return "CORE_KUALI"
    if is_lookup_target and row_count is not None and row_count <= REFERENCE_ROW_CEILING:
        return "LOOKUP_REFERENCE"
    if is_lookup_target and row_count is None and not RE_TRANSACTIONAL.search(table):
        return "LOOKUP_REFERENCE"
    return "CORE_KUALI"


# Fallback when no production row count is available for a table.
RE_TRANSACTIONAL = re.compile(
    r"^(AWARD|PROPOSAL|SUBAWARD|NEGOTIATION|BUDGET|EPS_PROPOSAL|PROTOCOL)$"
)


def mapping_priority(module, column, ui_label, origin, is_pk):
    """How much attention Huron's tooling should give this field."""
    if column in TECHNICAL_COLUMNS:
        return "NOT_FOR_HURON"
    if column in LINEAGE_KEYS or is_pk:
        return "HIGH"
    if origin in ("BU_EXTENSION", "BU_CUSTOM_ATTRIBUTE"):
        return "HIGH"
    if ui_label and module in BUSINESS_MODULES:
        return "HIGH"
    if ui_label:
        return "MEDIUM"
    if module in BUSINESS_MODULES:
        return "MEDIUM"
    return "LOW"


def load_prod_columns(path: Path):
    """table -> {column -> {data_type, max_length}} from the production extract."""
    prod = defaultdict(dict)
    if not path or not path.exists():
        return {}
    with path.open(encoding="utf-8") as f:
        for r in csv.DictReader(f):
            dt = r["DATA_TYPE"]
            if dt in ("VARCHAR2", "CHAR", "NVARCHAR2"):
                length = r["DATA_LENGTH"]
            elif dt == "NUMBER" and r.get("DATA_PRECISION"):
                length = f"{r['DATA_PRECISION']},{r['DATA_SCALE'] or 0}"
            else:
                length = ""
            prod[r["TABLE_NAME"]][r["COLUMN_NAME"]] = {
                "data_type": dt,
                "max_length": length,
            }
    return dict(prod)


def load_row_counts(path: Path):
    """table -> actual production row count."""
    counts = {}
    if not path or not path.exists():
        return counts
    with path.open(encoding="utf-8") as f:
        for r in csv.DictReader(f):
            try:
                counts[r["TABLE_NAME"]] = int(r["ACTUAL_ROWS"] or 0)
            except ValueError:
                pass
    return counts


def load_custom_attributes(path: Path):
    """Rows of the production CUSTOM_ATTRIBUTE catalog (attribute x document type)."""
    if not path or not path.exists():
        return []
    with path.open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, help="Kuali source root (read only)")
    ap.add_argument("--prod-columns", help="CSV from ALL_TAB_COLUMNS")
    ap.add_argument("--custom-attributes", help="CSV of the CUSTOM_ATTRIBUTE catalog")
    ap.add_argument("--row-counts", help="CSV of TABLE_NAME,ACTUAL_ROWS from production")
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    root = Path(args.source).expanduser()
    ojb_map, ojb_refs = parse_ojb(root)
    jpa_map, jpa_refs = parse_jpa(root)
    beans, bo_entries = parse_datadictionary(root)
    attr_index = build_attribute_index(beans, bo_entries)
    prod = load_prod_columns(Path(args.prod_columns).expanduser()) if args.prod_columns else {}
    ca_rows = load_custom_attributes(
        Path(args.custom_attributes).expanduser()) if args.custom_attributes else []
    row_counts = load_row_counts(
        Path(args.row_counts).expanduser()) if args.row_counts else {}

    # java_class -> candidate DD entries. A BO class is often claimed by several
    # entries (both "Organization" and "OrganizationMaintenanceDocument" declare
    # businessObjectClass=Organization) but the AttributeDefinition beans live under
    # only one. Keep every candidate; prefer the entry named like the class.
    class_to_entries = defaultdict(list)
    for entry, meta in bo_entries.items():
        class_to_entries[meta["bo_class"]].append(entry)
    for cls, entries in class_to_entries.items():
        simple = cls.split(".")[-1]
        entries.sort(key=lambda e: (e != simple, len(e)))

    # merged ORM view: OJB first (authoritative for legacy BOs), then JPA
    merged = {}
    for orm, mapping in (("OJB", ojb_map), ("JPA", jpa_map)):
        for cls, meta in mapping.items():
            merged.setdefault(cls, {**meta, "orm": orm})

    pk_of = {}
    for cls, meta in merged.items():
        pks = [f["column"] for f in meta["fields"].values() if f["pk"]]
        if pks:
            pk_of[cls] = pks[0]

    # Tables that other tables point at via a foreign key are reference objects.
    lookup_targets = set()
    for cls, refs in list(ojb_refs.items()) + list(jpa_refs.items()):
        for r in refs.values():
            tc = r.get("class_ref")
            if tc and tc in merged and merged[tc]["table"] not in NON_LOOKUP_TABLES:
                lookup_targets.add(merged[tc]["table"])

    rows = []
    for cls, meta in merged.items():
        table = meta["table"]
        entries = class_to_entries.get(cls, [])
        module = classify_module(cls, table)
        refs = ojb_refs.get(cls, {}) or jpa_refs.get(cls, {})

        fk_lookup = {}
        for r in refs.values():
            tc = r.get("class_ref")
            if not tc or tc not in merged:
                continue
            ttable = merged[tc]["table"]
            if ttable in NON_LOOKUP_TABLES:
                continue
            for fk in r.get("fk_fields", []):
                fk_lookup.setdefault(fk, (ttable, pk_of.get(tc, "")))

        for prop, f in meta["fields"].items():
            col = f["column"]

            # try each candidate DD entry until one yields a definition
            dd = None
            for e in entries:
                dd = attr_index.get((e, prop))
                if dd:
                    break

            ui_label = (dd["label"] or dd["short_label"]) if dd else ""
            description = (dd["description"] or dd["summary"]) if dd else ""
            lookup_table, lookup_col = fk_lookup.get(prop, ("", ""))

            colmeta = prod.get(table, {}).get(col, {})
            data_type = colmeta.get("data_type", "")
            max_length = colmeta.get("max_length", "") or (dd["max_length"] if dd else "")

            notes = []
            verified = None
            if prod:
                if table in prod:
                    verified = col in prod[table]
                    if not verified:
                        notes.append("column not present in KCOEUS production")
                else:
                    notes.append("table not present in KCOEUS production")

            if not ui_label:
                notes.append("no DataDictionary label in source; UI name not asserted")
            elif dd and not dd["own_label"]:
                notes.append(
                    "label inherited via Spring parent bean from "
                    + os.path.basename(dd["source"])
                )

            if verified is False or (prod and table not in prod):
                confidence = "LOW"
            elif ui_label and verified:
                confidence = "HIGH"
            elif verified:
                confidence = "MEDIUM"
            else:
                confidence = "LOW"

            origin = classify_origin(
                table, table in lookup_targets, row_counts.get(table))
            priority = mapping_priority(module, col, ui_label, origin, f["pk"])

            src = [os.path.relpath(f["source"], root)]
            if dd:
                src.append(os.path.relpath(dd["source"], root))

            rows.append({
                "MODULE": module,
                "FIELD_ORIGIN": origin,
                "DB_TABLE": table,
                "DB_COLUMN": col,
                "JAVA_OBJECT": cls,
                "JAVA_PROPERTY": prop,
                "UI_FIELD_NAME": ui_label,
                "FIELD_DESCRIPTION": description,
                "LOOKUP_TABLE": lookup_table,
                "LOOKUP_COLUMN": lookup_col,
                "CUSTOM_ATTRIBUTE_ID": "",
                "GROUP_NAME": "",
                "DATA_TYPE": data_type,
                "MAX_LENGTH": max_length,
                "MODULE_USAGE": "",
                "SOURCE_FILE": " | ".join(src),
                "CONFIDENCE": confidence,
                "MAPPING_PRIORITY": priority,
                "NOTES": "; ".join(notes),
                "_pk": f["pk"],
            })

    # ---- dedupe: keep the most authoritative BO per (table, column) ----
    CONF_RANK = {"HIGH": 2, "MEDIUM": 1, "LOW": 0}
    best, alternates = {}, defaultdict(set)
    for r in rows:
        key = (r["DB_TABLE"], r["DB_COLUMN"])
        alternates[key].add(r["JAVA_OBJECT"])
        score = (
            1 if r["UI_FIELD_NAME"] else 0,
            CONF_RANK.get(r["CONFIDENCE"], 0),
            0 if re.search(r"(BoLite|Lite|Contract)$", r["JAVA_OBJECT"]) else 1,
            1 if r["LOOKUP_TABLE"] else 0,
        )
        if key not in best or score > best[key][0]:
            best[key] = (score, r)

    rows = []
    for key, (_s, r) in best.items():
        others = sorted(alternates[key] - {r["JAVA_OBJECT"]})
        if others:
            extra = "also mapped by " + ", ".join(o.split(".")[-1] for o in others)
            r["NOTES"] = f"{r['NOTES']}; {extra}" if r["NOTES"] else extra
        r.pop("_pk", None)
        rows.append(r)

    # ---------------------------------------------------------------
    # BU custom attributes as first-class logical fields.
    #
    # The logical identity is CUSTOM_ATTRIBUTE_ID + its definition, not the
    # physical VALUE column. Module applicability comes from
    # CUSTOM_ATTRIBUTE_DOCUMENT.DOCUMENT_TYPE_CODE -- authoritative configuration --
    # and observed value counts are reported only as corroboration.
    # ---------------------------------------------------------------
    ca_emitted = 0
    for ca in ca_rows:
        doc_type = (ca.get("DOCUMENT_TYPE_CODE") or "").strip()
        module = DOC_TYPE_MODULE.get(doc_type)
        if not module:
            module = "BU custom fields (not attached to a document type)"
        table = DOC_TYPE_TABLE.get(doc_type, "CUSTOM_ATTRIBUTE_DOC_VALUE")

        usage_col = USAGE_COLUMN.get(doc_type)
        observed = ca.get(usage_col, "") if usage_col else ca.get("DOC_VALUE_ROWS", "")
        distinct = ca.get(usage_col.replace("_VALUE_ROWS", "_DISTINCT_VALUES"), "") \
            if usage_col else ca.get("DOC_DISTINCT_VALUES", "")

        usage = f"{doc_type or 'UNATTACHED'}: {observed or 0} value rows"
        if distinct:
            usage += f", {distinct} distinct values"

        notes = [
            "logical field = CUSTOM_ATTRIBUTE_ID "
            f"{ca['CUSTOM_ATTRIBUTE_ID']}; physical storage is the generic "
            f"{table}.VALUE column",
            "module applicability from CUSTOM_ATTRIBUTE_DOCUMENT, not inferred from data",
        ]
        if (ca.get("ACTIVE_FLAG") or "").strip() == "N":
            notes.append("marked inactive in CUSTOM_ATTRIBUTE_DOCUMENT")
        if (ca.get("IS_REQUIRED") or "").strip() == "Y":
            notes.append("required field")
        if not doc_type:
            notes.append("NOT attached to any document type - confirm with BU")
        try:
            if int(observed or 0) > 0 and int(distinct or 0) == 0:
                notes.append(
                    "value rows exist but every value is NULL - field configured "
                    "but never populated; confirm whether BU still uses it")
        except ValueError:
            pass

        rows.append({
            "MODULE": module,
            "FIELD_ORIGIN": "BU_CUSTOM_ATTRIBUTE",
            "DB_TABLE": table,
            "DB_COLUMN": "VALUE",
            "JAVA_OBJECT": "",
            "JAVA_PROPERTY": "value",
            "UI_FIELD_NAME": ca.get("ATTRIBUTE_LABEL", ""),
            "FIELD_DESCRIPTION": ca.get("ATTRIBUTE_NAME", ""),
            "LOOKUP_TABLE": "CUSTOM_ATTRIBUTE",
            "LOOKUP_COLUMN": "ID",
            "CUSTOM_ATTRIBUTE_ID": ca.get("CUSTOM_ATTRIBUTE_ID", ""),
            "GROUP_NAME": ca.get("GROUP_NAME", ""),
            "DATA_TYPE": ca.get("DATA_TYPE_DESC") or ca.get("DATA_TYPE_CODE", ""),
            "MAX_LENGTH": ca.get("DATA_LENGTH", ""),
            "MODULE_USAGE": usage,
            "SOURCE_FILE": "KCOEUS.CUSTOM_ATTRIBUTE + CUSTOM_ATTRIBUTE_DOCUMENT (production)",
            "CONFIDENCE": "HIGH",
            "MAPPING_PRIORITY": "HIGH",
            "NOTES": "; ".join(notes),
        })
        ca_emitted += 1

    rows.sort(key=lambda r: (r["MODULE"], r["DB_TABLE"],
                             r["CUSTOM_ATTRIBUTE_ID"] or "", r["DB_COLUMN"]))

    fieldnames = [
        "MODULE", "FIELD_ORIGIN", "DB_TABLE", "DB_COLUMN", "JAVA_OBJECT",
        "JAVA_PROPERTY", "UI_FIELD_NAME", "FIELD_DESCRIPTION", "LOOKUP_TABLE",
        "LOOKUP_COLUMN", "CUSTOM_ATTRIBUTE_ID", "GROUP_NAME", "DATA_TYPE",
        "MAX_LENGTH", "MODULE_USAGE", "SOURCE_FILE", "CONFIDENCE",
        "MAPPING_PRIORITY", "NOTES",
    ]
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)

    print(f"OJB classes    : {len(ojb_map)}")
    print(f"JPA classes    : {len(jpa_map)}")
    print(f"DD BO entries  : {len(bo_entries)}")
    print(f"DD attributes  : {len(attr_index)}")
    print(f"Custom attrs   : {ca_emitted} rows from production CUSTOM_ATTRIBUTE")
    print(f"Rows written   : {len(rows)} -> {out}")
    print("FIELD_ORIGIN   :", dict(Counter(r["FIELD_ORIGIN"] for r in rows)))
    print("PRIORITY       :", dict(Counter(r["MAPPING_PRIORITY"] for r in rows)))
    print("CONFIDENCE     :", dict(Counter(r["CONFIDENCE"] for r in rows)))
    print("With UI label  :", sum(1 for r in rows if r["UI_FIELD_NAME"]))


if __name__ == "__main__":
    main()
