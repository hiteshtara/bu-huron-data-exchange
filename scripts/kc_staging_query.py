#!/usr/bin/env python3

"""
BU Kuali Coeus STAGING read-only Oracle query runner.

Purpose:
    Allows Claude Code and developers to run SELECT queries against
    the BU KCOEUS staging database without storing the Oracle password
    in the repository.

Safety:
    - STAGING host is hard-coded.
    - Username is hard-coded as KCOEUS.
    - Password is retrieved from macOS Keychain.
    - Only SELECT/WITH queries are accepted.
    - Oracle transaction is explicitly READ ONLY.
"""

import argparse
import csv
import io
import subprocess
import sys
from pathlib import Path

try:
    import oracledb
except ImportError:
    print(
        "Missing python-oracledb.\n"
        "Run:\n"
        "  uv venv .venv\n"
        "  uv pip install --python .venv/bin/python oracledb",
        file=sys.stderr,
    )
    sys.exit(1)


DB_HOST = "stg.db.kualitest.research.bu.edu"
DB_PORT = 1521
DB_SID = "kuali"
DB_USER = "KCOEUS"

KEYCHAIN_SERVICE = "bu-kuali-stg"
KEYCHAIN_ACCOUNT = DB_USER


def get_password():
    """Read the staging Oracle password from macOS Keychain."""
    result = subprocess.run(
        [
            "security",
            "find-generic-password",
            "-s",
            KEYCHAIN_SERVICE,
            "-a",
            KEYCHAIN_ACCOUNT,
            "-w",
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(
            "Kuali staging password was not found in macOS Keychain.\n"
            "Run scripts/setup_kc_staging_keychain.sh first.",
            file=sys.stderr,
        )
        sys.exit(2)

    return result.stdout.strip()


def clean_sql(sql):
    sql = sql.strip()

    # SQL Developer commonly leaves a trailing semicolon.
    if sql.endswith(";"):
        sql = sql[:-1].strip()

    return sql


def validate_read_only(sql):
    """
    Only permit SELECT or WITH queries.

    This intentionally prevents Claude from issuing INSERT, UPDATE,
    DELETE, MERGE, DROP, ALTER, TRUNCATE, CREATE, GRANT, etc.
    """
    normalized = sql.lstrip().upper()

    if not (
        normalized.startswith("SELECT ")
        or normalized.startswith("SELECT\n")
        or normalized.startswith("WITH ")
        or normalized.startswith("WITH\n")
    ):
        raise ValueError(
            "Only SELECT and WITH queries are permitted by this runner."
        )

    blocked = [
        " INSERT ",
        " UPDATE ",
        " DELETE ",
        " MERGE ",
        " DROP ",
        " TRUNCATE ",
        " CREATE ",
        " ALTER ",
        " GRANT ",
        " REVOKE ",
        " COMMIT ",
        " ROLLBACK ",
    ]

    padded = f" {normalized} "

    for word in blocked:
        if word in padded:
            raise ValueError(
                f"Blocked potentially modifying statement: {word.strip()}"
            )


def connect():
    password = get_password()

    dsn = oracledb.makedsn(
        DB_HOST,
        DB_PORT,
        sid=DB_SID,
    )

    conn = oracledb.connect(
        user=DB_USER,
        password=password,
        dsn=dsn,
    )

    return conn


def run_query(sql, output_file=None, limit=None):
    sql = clean_sql(sql)
    validate_read_only(sql)

    conn = connect()

    try:
        cursor = conn.cursor()

        # Extra database-level protection.
        cursor.execute("SET TRANSACTION READ ONLY")

        cursor.execute(sql)

        columns = [column[0] for column in cursor.description]

        if output_file:
            output_path = Path(output_file)
            output_path.parent.mkdir(parents=True, exist_ok=True)

            with output_path.open(
                "w",
                newline="",
                encoding="utf-8",
            ) as f:
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

            print(f"Wrote {count:,} rows to {output_path}")
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


def test_connection():
    conn = connect()

    try:
        cursor = conn.cursor()
        cursor.execute("SET TRANSACTION READ ONLY")

        cursor.execute(
            """
            SELECT
                SYS_CONTEXT('USERENV', 'DB_NAME') AS db_name,
                SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS current_schema,
                SYS_CONTEXT('USERENV', 'SESSION_USER') AS session_user
            FROM dual
            """
        )

        row = cursor.fetchone()

        print("Connection successful")
        print(f"Host:           {DB_HOST}")
        print(f"Database:       {row[0]}")
        print(f"Current schema: {row[1]}")
        print(f"Session user:   {row[2]}")
        print("Mode:           READ ONLY")

    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(
        description="BU KCOEUS staging read-only Oracle query runner"
    )

    group = parser.add_mutually_exclusive_group()

    group.add_argument(
        "--sql",
        help="SQL SELECT statement",
    )

    group.add_argument(
        "--file",
        help="SQL file containing one SELECT/WITH statement",
    )

    parser.add_argument(
        "--output",
        help="Write query result to CSV",
    )

    parser.add_argument(
        "--limit",
        type=int,
        help="Maximum number of rows to return",
    )

    parser.add_argument(
        "--test",
        action="store_true",
        help="Test database connection",
    )

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

    try:
        run_query(
            sql,
            output_file=args.output,
            limit=args.limit,
        )
    except ValueError as exc:
        print(f"SAFETY ERROR: {exc}", file=sys.stderr)
        sys.exit(3)


if __name__ == "__main__":
    main()
