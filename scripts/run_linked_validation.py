#!/usr/bin/env python3
"""Run multi-statement validation SQL on linked Supabase via `supabase db query --linked`."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def strip_psql_directives(sql: str) -> str:
    lines = []
    for line in sql.splitlines():
        if line.strip().startswith("\\"):
            continue
        lines.append(line)
    return "\n".join(lines)


def strip_line_comments(sql: str) -> str:
    return re.sub(r"--[^\n]*", "", sql)


def split_statements(sql: str) -> list[str]:
    sql = strip_line_comments(sql)
    statements: list[str] = []
    last = 0
    for match in re.finditer(r"do \$\$.*?end \$\$;", sql, re.IGNORECASE | re.DOTALL):
        before = sql[last : match.start()].strip()
        if before:
            for part in before.split(";"):
                part = part.strip()
                if part and not part.lower().startswith("raise notice"):
                    statements.append(part + ";")
        statements.append(match.group(0).strip())
        last = match.end()

    tail = sql[last:].strip()
    if tail:
        for part in tail.split(";"):
            part = part.strip()
            if part and not part.lower().startswith("raise notice"):
                statements.append(part + ";")

    return statements


def run_statement(name: str, index: int, total: int, sql: str) -> None:
    preview = re.sub(r"\s+", " ", sql)[:100]
    print(f"\n[{name}] block {index}/{total}: {preview}...")
    result = subprocess.run(
        ["npx", "supabase", "db", "query", "--linked", sql],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    out = (result.stdout or "") + (result.stderr or "")
    if result.returncode != 0:
        print(out)
        raise SystemExit(f"FAILED [{name}] block {index}/{total}")
    if "SQLSTATE" in out or '"error"' in out.lower():
        print(out)
        raise SystemExit(f"FAILED [{name}] block {index}/{total}")
    print("  OK")


def run_file(path: Path) -> None:
    print(f"\n{'=' * 72}\nRUNNING {path.name}\n{'=' * 72}")
    sql = strip_psql_directives(path.read_text())
    statements = split_statements(sql)
    if not statements:
        raise SystemExit(f"No statements found in {path}")
    for idx, stmt in enumerate(statements, start=1):
        run_statement(path.name, idx, len(statements), stmt)
    print(f"\nPASSED {path.name} ({len(statements)} blocks)")


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: run_linked_validation.py <script.sql> [...]", file=sys.stderr)
        raise SystemExit(2)
    for arg in sys.argv[1:]:
        run_file(Path(arg))


if __name__ == "__main__":
    main()
