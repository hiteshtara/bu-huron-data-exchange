#!/usr/bin/env python3
"""
Classify every KCOEUS production table for the Huron Grants discovery package.

Reads the production discovery extracts (table inventory, real row counts, column
metadata) and produces:

  * 02_table_manifest.csv  - one row per IN-SCOPE table: domain, extract type,
                             row/column counts, key columns, PII flag
  * 02_excluded_tables.csv - one row per EXCLUDED table with an explicit reason

Exclusion is deliberately conservative and reason-coded. A table is only excluded
as a backup/temp/repair copy when its name carries an unambiguous marker (dated
suffix, _BKUP/_BAK, BU_TEMP_, _DELETED, _FIX_). Legitimate KC objects whose names
merely contain "TEMPLATE" or "RESEARCH_AREAS" are NOT excluded.

Extract types:
  FULL   - small reference/master/lookup table; send every row so coded values decode
  SAMPLE - large transactional/history table; send a representative row sample,
           retaining ALL columns and ALL lineage keys
  EMPTY  - zero rows in production; columns still documented in the data dictionary
           (fields matter more than rows) but no data file is produced
"""

import argparse
import csv
import re
from collections import defaultdict
from pathlib import Path

# Rows at or below this are treated as reference/master data worth sending in full.
FULL_EXTRACT_CEILING = 20_000

# ---------------------------------------------------------------------------
# Exclusion rules. Each is (reason_code, compiled pattern).
# Order matters: the first match wins.
# ---------------------------------------------------------------------------
EXCLUSION_RULES = [
    ("BACKUP_COPY", re.compile(
        r"(_BKUP|_BKP|_BAK\d*|_BACKUP)(_|\d|$)|_BKUP$|_BAK$", re.I)),
    ("DATED_SNAPSHOT", re.compile(r"_(19|20)\d{2}(\d{2})?(\d{2})?$")),
    ("DATED_SNAPSHOT", re.compile(r"_\d{4}[A-Z]?$")),
    ("DELETED_ROWS_COPY", re.compile(r"_DELETED$", re.I)),
    ("REPAIR_FIX_TABLE", re.compile(r"_FIX(_|\d|$)|OHRP_FIX", re.I)),
    ("BU_TEMP_WORKING", re.compile(r"^BU_TEMP_", re.I)),
    ("TEMP_WORKING", re.compile(r"^(TEMP_|TMP_|GTT_)", re.I)),
    ("SMOKE_TEST", re.compile(r"SMOKE_TEST|^TST_", re.I)),
    ("VERSION_SNAPSHOT", re.compile(r"^VH_", re.I)),
]

# Out-of-scope subject areas (different Huron module, or platform infrastructure).
OUT_OF_SCOPE_RULES = [
    ("IRB_IACUC_MODULE", re.compile(
        r"^(IACUC|PROTOCOL|PROTO_|IRB_|COMMITTEE|COMM_|CRC_|MINUTE|EXEMPT|"
        r"EXPEDITED|VULNERABLE|SCHEDULE|SUBMISSION|REVIEWER|RISK_LEVEL|"
        r"VALID_PROTO|VALID_IACUC|TRAINING|PERSON_TRAINING)", re.I)),
    ("WORKFLOW_IDENTITY_INFRA", re.compile(
        r"^(KREW|KRIM|KRMS|KRNS|KRSB|KREN|KRCR|KRLC|KRAD|KC_QRTZ|KRA_USER|"
        r"FP_DOC_TYPE|TRV_ACCT|ACCT_DD_ATTR|CORE_IMPERSONATION|REST_AUDIT|"
        r"DATA_DICTIONARY_OVERRIDE|DOCUMENT_ACCESS|DOCUMENT_WORKFLOW|"
        r"DOCUMENT_WORKLOAD|MSG_OF_THE_DAY|DASH_BOARD|WATERMARK|"
        r"FORMS_XML_REORDER|BATCH_CORRESPONDENCE|NOTIFICATION|CX_HRAPI)", re.I)),
    ("QUESTIONNAIRE_MODULE", re.compile(r"^(QUESTION|YNQ|ANSWER)", re.I)),
    ("PMC_MODULE", re.compile(r"^PMC", re.I)),
]

# ---------------------------------------------------------------------------
# Domain assignment. First match wins, so custom/extension patterns come first.
# ---------------------------------------------------------------------------
DOMAIN_RULES = [
    ("BU custom fields", re.compile(
        r"_CUSTOM_DATA$|^CUSTOM_ATTRIBUTE|_EXTENSION$|^BU_(?!TEMP_)", re.I)),
    ("Award", re.compile(
        r"^AWARD|^AWD_|^TIME_AND_MONEY|^PENDING_TRANSACTIONS|^TRANSACTION_DETAILS", re.I)),
    ("Institutional Proposal", re.compile(
        r"^PROPOSAL|^IP_|^INSTITUTE_PROPOSAL", re.I)),
    ("Proposal / pre-award", re.compile(
        r"^EPS_|^BUDGET|^BUD_|^NARRATIVE|^S2S_|^SUBCONTRACTING_BUD", re.I)),
    ("Subaward", re.compile(r"^SUBAWARD|^SUBCONTRACT|^SUB_EXP", re.I)),
    ("Negotiation", re.compile(r"^NEGOTIATION", re.I)),
    ("Sponsor", re.compile(r"^SPONSOR", re.I)),
    ("Organization", re.compile(r"^ORGANIZATION", re.I)),
    ("Unit", re.compile(r"^UNIT|^KUALI_UNIT_ORG_MAP|^SOURCE_UNIT", re.I)),
]

# Cross-cutting reference/lookup tables that carry no module prefix. Explicit list
# so nothing is swept in by accident.
REFERENCE_TABLES = {
    "ABSTRACT_TYPE", "ACCOUNT", "ACCOUNT_TYPE", "ACTIVITY_TYPE", "AFFILIATION_TYPE",
    "APPOINTMENT_TYPE", "ARG_VALUE_LOOKUP", "ATTACHMENTS_TYPE", "ATTACHMENT_FILE",
    "CARRIER_TYPE", "CFDA", "CITIZENSHIP_TYPE_T", "CLOSEOUT_REPORT_TYPE",
    # COMMENT_TYPE decodes COMMENT_TYPE_CODE on AWARD_COMMENT, PROPOSAL_COMMENTS
    # and SUBAWARD_COMMENT (confirmed via foreign keys), so it is Grants reference
    # data despite having no module prefix.
    "CLOSEOUT_TYPE", "COEUS_MODULE", "COEUS_SUB_MODULE", "COMMENT_TYPE",
    "PROP_ROLE_TEMPLATE", "CONTACT_TYPE",
    "CONTACT_USAGE", "CORRESPONDENT_TYPE", "COST_ELEMENT", "COST_SHARE_TYPE",
    "DEADLINE_TYPE", "DEGREE_TYPE", "DISTRIBUTION", "DOCUMENT_NEXTVALUE",
    "FILE_DATA", "FIN_IDC_TYPE_CODE", "FIN_OBJECT_CODE_MAPPING", "FORMULATED_TYPE",
    "FREQUENCY", "FREQUENCY_BASE", "FUNDING_SOURCE_TYPE", "GROUP_TYPES",
    "IDC_RATE_TYPE", "INSTITUTE_LA_RATES", "INSTITUTE_RATES", "INV_CREDIT_TYPE",
    "JOB_CODE", "LOCATION_TYPE", "MAIL_BY", "MAIL_TYPE", "NIH_VALIDATION_MAPPING",
    "NOTICE_OF_OPPORTUNITY", "NSF_CODES", "PERSON_APPOINTMENT", "PERSON_BIOSKETCH",
    "PERSON_CUSTOM_DATA", "PERSON_DEGREE", "PERSON_EDITABLE_FIELDS",
    "PERSON_EXT_T", "PERSON_MASS_CHANGE", "PERSON_MASS_CHANGE_DOCUMENT",
    "PERSON_SIGNATURE", "PERSON_SIGNATURE_MODULE", "RATE_CLASS",
    "RATE_CLASS_BASE_EXCLUSION", "RATE_CLASS_BASE_INCLUSION", "RATE_CLASS_TYPE",
    "RATE_TYPE", "REPORT", "REPORT_CLASS", "REPORT_STATUS", "RESEARCH_AREAS",
    "RIGHTS", "ROLE", "ROLE_RIGHTS", "ROLODEX", "SCHOOL_CODE", "SCIENCE_KEYWORD",
    "SPECIAL_REVIEW", "SPECIAL_REVIEW_USAGE", "SP_REV_APPROVAL_TYPE", "TBN",
    "TARGET_ROLE", "TRAINING_STIPEND_RATES", "USER_ROLES", "VALID_AWARD_BASIS_PAYMENT",
    "VALID_BASIS_METHOD_PMT", "VALID_CALC_TYPES", "VALID_CE_JOB_CODES",
    "VALID_CE_RATE_TYPES", "VALID_CLASS_REPORT_FREQ", "VALID_FREQUENCY_BASE",
    "VALID_NARR_FORMS", "VALID_RATES", "VALID_SP_REV_APPROVAL", "VAL_SRC_ACNTS_COST_TYP",
    "VERSION_HISTORY",
}

# Tables holding personal data. Sent as column structure + small masked sample only.
PII_TABLES = {
    "ROLODEX", "PERSON_EXT_T", "PERSON_APPOINTMENT", "PERSON_DEGREE",
    "PERSON_BIOSKETCH", "PERSON_SIGNATURE", "PERSON_CUSTOM_DATA",
    "AWARD_SPONSOR_CONTACTS", "SUBAWARD_CONTACT", "AWARD_UNIT_CONTACTS",
    "PROPOSAL_UNIT_CONTACTS", "AWARD_PERSONS", "PROPOSAL_PERSONS",
    "BUDGET_PERSONS", "BUDGET_PERSON_SALARY_DETAILS", "PERSON_MASS_CHANGE",
}

# Large binary/attachment payload tables: structure is useful, content is not.
BLOB_TABLES = {
    "ATTACHMENT_FILE", "FILE_DATA", "AWARD_ATTACHMENT", "PROPOSAL_ATTACHMENTS",
    "SUBAWARD_ATTACHMENTS", "NEGOTIATION_ATTACHMENT", "SUBAWARD_TEMPLATE_ATTACHMENTS",
}


def excluded_reason(table):
    for code, rx in EXCLUSION_RULES:
        if rx.search(table):
            return code
    for code, rx in OUT_OF_SCOPE_RULES:
        if rx.search(table):
            return code
    return None


def domain_of(table):
    for dom, rx in DOMAIN_RULES:
        if rx.search(table):
            return dom
    if table in REFERENCE_TABLES:
        return "Reference / lookup"
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tables", required=True)
    ap.add_argument("--row-counts", required=True)
    ap.add_argument("--columns", required=True)
    ap.add_argument("--constraints", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--excluded", required=True)
    args = ap.parse_args()

    tables = {r["TABLE_NAME"]: r for r in csv.DictReader(open(args.tables, encoding="utf-8"))}
    counts = {
        r["TABLE_NAME"]: int(r["ACTUAL_ROWS"] or 0)
        for r in csv.DictReader(open(args.row_counts, encoding="utf-8"))
    }

    cols = defaultdict(list)
    for r in csv.DictReader(open(args.columns, encoding="utf-8")):
        cols[r["TABLE_NAME"]].append(r)

    pk_cols = defaultdict(list)
    for r in csv.DictReader(open(args.constraints, encoding="utf-8")):
        if r["CONSTRAINT_TYPE"] == "P" and r["COLUMN_NAME"]:
            pk_cols[r["TABLE_NAME"]].append((int(r["POSITION"] or 0), r["COLUMN_NAME"]))

    LINEAGE = [
        "AWARD_ID", "AWARD_NUMBER", "PROPOSAL_ID", "PROPOSAL_NUMBER", "SUBAWARD_ID",
        "SUBAWARD_CODE", "NEGOTIATION_ID", "NEGOTIATION_NUMBER", "SEQUENCE_NUMBER",
        "DOCUMENT_NUMBER", "SPONSOR_CODE", "UNIT_NUMBER", "ORGANIZATION_ID",
        "PERSON_ID", "ROLODEX_ID", "CUSTOM_ATTRIBUTE_ID", "BUDGET_ID",
    ]

    manifest, excluded = [], []

    for table in sorted(tables):
        rows_n = counts.get(table, 0)
        col_list = [c["COLUMN_NAME"] for c in cols.get(table, [])]

        reason = excluded_reason(table)
        if reason:
            excluded.append({
                "TABLE_NAME": table,
                "EXCLUSION_REASON": reason,
                "ROW_COUNT": rows_n,
                "COLUMN_COUNT": len(col_list),
                "NOTE": "excluded from Huron discovery package",
            })
            continue

        domain = domain_of(table)
        if domain is None:
            excluded.append({
                "TABLE_NAME": table,
                "EXCLUSION_REASON": "NOT_GRANTS_SCOPE",
                "ROW_COUNT": rows_n,
                "COLUMN_COUNT": len(col_list),
                "NOTE": "no Grants domain rule matched; review if BU expects it",
            })
            continue

        if rows_n == 0:
            extract = "EMPTY"
        elif table in BLOB_TABLES:
            extract = "SAMPLE"
        elif rows_n <= FULL_EXTRACT_CEILING:
            extract = "FULL"
        else:
            extract = "SAMPLE"

        pk = ",".join(c for _, c in sorted(pk_cols.get(table, [])))
        lineage = ",".join(k for k in LINEAGE if k in col_list)

        notes = []
        if table in PII_TABLES:
            notes.append("PII: send column structure + masked sample only")
        if table in BLOB_TABLES:
            notes.append("binary payload: send metadata columns, not file content")
        if table.endswith("_CUSTOM_DATA"):
            notes.append("EAV: join to CUSTOM_ATTRIBUTE; see custom_fields/ extracts")
        if table.endswith("_EXTENSION"):
            notes.append("BU extension table")
        if rows_n == 0:
            notes.append("no rows in production; columns documented, no data file")

        manifest.append({
            "DOMAIN": domain,
            "TABLE_NAME": table,
            "EXTRACT_TYPE": extract,
            "ROW_COUNT": rows_n,
            "COLUMN_COUNT": len(col_list),
            "PRIMARY_KEY": pk,
            "LINEAGE_KEYS": lineage,
            "CONTAINS_PII": "Y" if table in PII_TABLES else "N",
            "NOTES": "; ".join(notes),
        })

    Path(args.manifest).parent.mkdir(parents=True, exist_ok=True)
    with open(args.manifest, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=[
            "DOMAIN", "TABLE_NAME", "EXTRACT_TYPE", "ROW_COUNT", "COLUMN_COUNT",
            "PRIMARY_KEY", "LINEAGE_KEYS", "CONTAINS_PII", "NOTES"])
        w.writeheader()
        w.writerows(sorted(manifest, key=lambda r: (r["DOMAIN"], r["TABLE_NAME"])))

    with open(args.excluded, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=[
            "TABLE_NAME", "EXCLUSION_REASON", "ROW_COUNT", "COLUMN_COUNT", "NOTE"])
        w.writeheader()
        w.writerows(sorted(excluded, key=lambda r: (r["EXCLUSION_REASON"], r["TABLE_NAME"])))

    from collections import Counter
    print(f"included : {len(manifest)} tables")
    print(f"excluded : {len(excluded)} tables")
    print("by domain:")
    for k, v in sorted(Counter(r["DOMAIN"] for r in manifest).items()):
        print(f"   {k:32s} {v}")
    print("by extract type:", dict(Counter(r["EXTRACT_TYPE"] for r in manifest)))
    print("exclusion reasons:")
    for k, v in sorted(Counter(r["EXCLUSION_REASON"] for r in excluded).items()):
        print(f"   {k:26s} {v}")
    print("columns in scope:", sum(r["COLUMN_COUNT"] for r in manifest))


if __name__ == "__main__":
    main()
