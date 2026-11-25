#!/usr/bin/env python3
"""Load the semicolon-delimited campaign CSV and run campaign_analysis.sql.

Handles the UTF-8 BOM on the ID header. Creates a TEXT table named `raw`,
matching a SQLite CLI .import, then executes sql/campaign_analysis.sql.
"""

from __future__ import annotations

import csv
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "data" / "marketing_campaign.csv"
SQL_PATH = ROOT / "sql" / "campaign_analysis.sql"


def split_sql_statements(script: str) -> list[str]:
    """Split on semicolons that are not inside quotes or line comments."""
    statements = []
    buf: list[str] = []
    i = 0
    in_single = False
    while i < len(script):
        ch = script[i]
        nxt = script[i + 1] if i + 1 < len(script) else ""
        if not in_single and ch == "-" and nxt == "-":
            while i < len(script) and script[i] != "\n":
                i += 1
            buf.append("\n")
            continue
        if ch == "'":
            buf.append(ch)
            if in_single and nxt == "'":
                buf.append(nxt)
                i += 2
                continue
            in_single = not in_single
            i += 1
            continue
        if ch == ";" and not in_single:
            stmt = "".join(buf).strip()
            if stmt:
                statements.append(stmt)
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        statements.append(tail)
    return statements


def main() -> int:
    if not CSV_PATH.exists():
        print(f"CSV not found: {CSV_PATH}", file=sys.stderr)
        return 1
    if not SQL_PATH.exists():
        print(f"SQL not found: {SQL_PATH}", file=sys.stderr)
        return 1

    conn = sqlite3.connect(":memory:")
    cur = conn.cursor()

    with CSV_PATH.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle, delimiter=";")
        columns = reader.fieldnames
        if not columns:
            print("CSV has no header row.", file=sys.stderr)
            return 1
        rows = list(reader)

    col_defs = ", ".join(f'"{name}" TEXT' for name in columns)
    cur.execute(f"CREATE TABLE raw ({col_defs})")
    placeholders = ", ".join("?" for _ in columns)
    cur.executemany(
        f"INSERT INTO raw VALUES ({placeholders})",
        [[row[name] for name in columns] for row in rows],
    )
    conn.commit()

    script = SQL_PATH.read_text(encoding="utf-8")
    statements = split_sql_statements(script)
    for statement in statements:
        try:
            cur.execute(statement)
        except sqlite3.Error as exc:
            preview = statement.replace("\n", " ")[:180]
            print(f"SQL error: {exc}\n  in: {preview}", file=sys.stderr)
            return 1
        if cur.description is None:
            continue
        headers = [col[0] for col in cur.description]
        fetched = cur.fetchall()
        print(" | ".join(headers))
        for record in fetched:
            print(
                " | ".join(
                    ""
                    if value is None
                    else (f"{value:.10f}".rstrip("0").rstrip(".") if isinstance(value, float) else str(value))
                    for value in record
                )
            )
        print()

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
