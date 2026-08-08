#!/usr/bin/env python3
"""
Produce the three production metadata files the builders take as input.

The regeneration commands in the module READMEs refer to <row-counts.csv>,
<columns.csv> and <catalog.csv>. Those are not committed — they are measurements of
production, and they go stale. This script makes them, so nobody has to reconstruct the
queries by hand.

    .venv/bin/python scripts/build_metadata_inputs.py --out-dir build/metadata

Everything it runs is a SELECT through scripts/kc_prod_readonly_query.py. Output is
schema metadata and row counts only — no business rows — but it is still production
information, so the default output directory is gitignored.
"""

import argparse
import subprocess
import sys
from pathlib import Path

RUNNER = Path("scripts/kc_prod_readonly_query.py")
PYTHON = Path(".venv/bin/python")

QUERIES = {
    "kcoeus_actual_rowcounts.csv": """
SELECT t.table_name,
       TO_NUMBER(
         EXTRACTVALUE(
           XMLTYPE(
             DBMS_XMLGEN.GETXML('SELECT COUNT(*) AS c FROM "'||t.owner||'"."'||t.table_name||'"')
           ), '/ROWSET/ROW/C')
       ) AS actual_rows
FROM   all_tables t
WHERE  t.owner = 'KCOEUS'
ORDER  BY t.table_name
""",
    "kcoeus_all_columns.csv": """
SELECT c.table_name, o.object_type, c.column_id, c.column_name, c.data_type,
       c.data_length, c.data_precision, c.data_scale, c.nullable, c.data_default,
       cc.comments AS column_comment
FROM   all_tab_columns c
JOIN   all_objects o ON o.owner = c.owner AND o.object_name = c.table_name
                    AND o.object_type IN ('TABLE','VIEW')
LEFT JOIN all_col_comments cc ON cc.owner = c.owner AND cc.table_name = c.table_name
                             AND cc.column_name = c.column_name
WHERE  c.owner = 'KCOEUS'
ORDER  BY c.table_name, c.column_id
""",
    "bu_custom_attribute_catalog.csv": """
WITH awd AS (
    SELECT custom_attribute_id, COUNT(*) AS value_rows,
           COUNT(DISTINCT value) AS distinct_values
    FROM award_custom_data GROUP BY custom_attribute_id
), prop AS (
    SELECT custom_attribute_id, COUNT(*) AS value_rows,
           COUNT(DISTINCT value) AS distinct_values
    FROM proposal_custom_data GROUP BY custom_attribute_id
), sub AS (
    SELECT custom_attribute_id, COUNT(*) AS value_rows,
           COUNT(DISTINCT value) AS distinct_values
    FROM subaward_custom_data GROUP BY custom_attribute_id
), neg AS (
    SELECT custom_attribute_id, COUNT(*) AS value_rows,
           COUNT(DISTINCT value) AS distinct_values
    FROM negotiation_custom_data GROUP BY custom_attribute_id
), docv AS (
    SELECT custom_attribute_id, COUNT(*) AS value_rows,
           COUNT(DISTINCT value) AS distinct_values
    FROM custom_attribute_doc_value GROUP BY custom_attribute_id
)
SELECT ca.id AS custom_attribute_id, ca.name AS attribute_name,
       ca.label AS attribute_label, ca.group_name, ca.data_type_code,
       cadt.description AS data_type_desc, ca.data_length, ca.default_value,
       ca.lookup_class, ca.lookup_return, cad.document_type_code,
       cad.type_name AS attached_module, cad.is_required, cad.active_flag,
       NVL(awd.value_rows,0)  AS award_value_rows,
       NVL(awd.distinct_values,0) AS award_distinct_values,
       NVL(prop.value_rows,0) AS proposal_value_rows,
       NVL(prop.distinct_values,0) AS proposal_distinct_values,
       NVL(sub.value_rows,0)  AS subaward_value_rows,
       NVL(sub.distinct_values,0) AS subaward_distinct_values,
       NVL(neg.value_rows,0)  AS negotiation_value_rows,
       NVL(neg.distinct_values,0) AS negotiation_distinct_values,
       NVL(docv.value_rows,0) AS doc_value_rows,
       NVL(docv.distinct_values,0) AS doc_distinct_values
FROM       custom_attribute ca
LEFT JOIN  custom_attribute_document  cad  ON cad.custom_attribute_id = ca.id
LEFT JOIN  custom_attribute_data_type cadt ON cadt.data_type_code = ca.data_type_code
LEFT JOIN  awd  ON awd.custom_attribute_id  = ca.id
LEFT JOIN  prop ON prop.custom_attribute_id = ca.id
LEFT JOIN  sub  ON sub.custom_attribute_id  = ca.id
LEFT JOIN  neg  ON neg.custom_attribute_id  = ca.id
LEFT JOIN  docv ON docv.custom_attribute_id = ca.id
ORDER  BY  cad.document_type_code, ca.group_name, ca.name
""",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default="build/metadata")
    args = ap.parse_args()

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    sql_dir = out / "sql"
    sql_dir.mkdir(exist_ok=True)

    failed = 0
    for name, sql in QUERIES.items():
        q = sql_dir / (name.replace(".csv", ".sql"))
        q.write_text(sql.strip() + "\n", encoding="utf-8")
        target = out / name
        proc = subprocess.run(
            [str(PYTHON), str(RUNNER), "--file", str(q), "--output", str(target)],
            capture_output=True, text=True,
        )
        if proc.returncode == 0:
            print(f"  {proc.stdout.strip()}")
        else:
            print(f"  FAILED {name}: {proc.stderr.strip().splitlines()[-1][:120]}")
            failed += 1

    if not failed:
        print(f"\nAll three written to {out}/. Use them like this:\n")
        print(f"  .venv/bin/python scripts/build_object_graph.py --module award \\")
        print(f"      --source ~/Downloads/kuali-research-bu-master \\")
        print(f"      --row-counts {out}/kcoeus_actual_rowcounts.csv \\")
        print(f"      --output modules/award/AWARD_GRAPH.csv")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
