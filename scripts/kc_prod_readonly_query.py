#!/usr/bin/env python3

import argparse
import csv
import subprocess
import sys
from pathlib import Path

try:
    import oracledb
except ImportError:
    print("Missing oracledb. Install with:")
    print("  uv venv .venv")
    print("  uv pip install --python .venv/bin/python oracledb")
    sys.exit(1)

# BU Kuali PRODUCTION
DB_HOST = "prod.db.kuali.research.bu.edu"
DB_PORT = 1521
DB_SID = "kuali"
DB_USER = "KCOEUS"

KEYCHAIN_SERVICE = "bu-kuali-prod-readonly"
KEYCHAIN_ACCOUNT = DB_USER


def get_password():
    result = subprocess.run(
        [
            "security",
            "find-generic-password",
            "-s", KEYCHAIN_SERVICE,
            "-a", KEYCHAIN_ACCOUNT,
            "-w",
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print("Production password not found in macOS Keychain.")
        print("Add it with:")
        print(
            '  security add-generic-password -U '
            '-a "KCOEUS" -s "bu-kuali-prod-readonly" -w'
        )
        sys.exit(2)

    return result.stdout.strip()


def validate_read_only(sql):
    normalized = sql.strip().upper()

    if not (normalized.startswith("SELECT") or normalized.startswith("WITH")):
        raise ValueError("Only SELECT and WITH statements are permitted.")

    blocked = [
        "INSERT", "UPDATE", "DELETE", "MERGE",
        "DROP", "TRUNCATE", "CREATE", "ALTER",
        "GRANT", "REVOKE"
    ]

    for keyword in blocked:
        if keyword in normalized.split():
            raise ValueError(
                f"Blocked production operation: {keyword}"
            )


def connect():
    password = get_password()

    dsn = oracledb.makedsn(
        DB_HOST,
        DB_PORT,
        sid=DB_SID,
    )

    return oracledb.connect(
        user=DB_USER,
        password=password,
        dsn=dsn,
    )


def test_connection():
    conn = connect()

    try:
        cursor = conn.cursor()

        cursor.execute("SET TRANSACTION READ ONLY")

        cursor.execute("""
            SELECT
                SYS_CONTEXT('USERENV','DB_NAME'),
                SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),
                SYS_CONTEXT('USERENV','SESSION_USER')
            FROM dual
        """)

        db_name, schema, session_user = cursor.fetchone()

        print()
        print("========================================")
        print(" BU KUALI PRODUCTION")
        print(" READ-ONLY CONNECTION")
        print("========================================")
        print(f"Host:           {DB_HOST}")
        print(f"Database:       {db_name}")
        print(f"Current schema: {schema}")
        print(f"Session user:   {session_user}")
        print("Mode:           READ ONLY")
        print("========================================")

    finally:
        conn.close()


def run_query(sql, output=None, limit=None):
    sql = sql.strip().rstrip(";")
    validate_read_only(sql)

    conn = connect()

    try:
        cursor = conn.cursor()

        cursor.execute("SET TRANSACTION READ ONLY")
        cursor.execute(sql)

        columns = [c[0] for c in cursor.description]

        if output:
            path = Path(output)
            path.parent.mkdir(parents=True, exist_ok=True)

            with path.open("w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(columns)

                count = 0

                while True:
                    rows = cursor.fetchmany(1000)

                    if not rows:
                        break

                    for row in rows:
                        writer.writerow(row)
                        count += 1

                        if limit and count >= limit:
                            break

                    if limit and count >= limit:
                        break

            print(f"Wrote {count:,} rows to {path}")
            return

        writer = csv.writer(sys.stdout)
        writer.writerow(columns)

        count = 0

        while True:
            rows = cursor.fetchmany(500)

            if not rows:
                break

            for row in rows:
                writer.writerow(row)
                count += 1

                if limit and count >= limit:
                    return

    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(
        description="BU Kuali production READ-ONLY Oracle query runner"
    )

    parser.add_argument("--test", action="store_true")
    parser.add_argument("--sql")
    parser.add_argument("--file")
    parser.add_argument("--output")
    parser.add_argument("--limit", type=int)

    args = parser.parse_args()

    if args.test:
        test_connection()
        return

    if args.file:
        sql = Path(args.file).read_text(encoding="utf-8")
    elif args.sql:
        sql = args.sql
    else:
        parser.error("Use --test, --sql, or --file")

    run_query(sql, args.output, args.limit)


if __name__ == "__main__":
    main()
