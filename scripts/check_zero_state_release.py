#!/usr/bin/env python3
"""Fail closed unless the Smart Meters release is a clean zero-state build."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_VERSION = "1.0.0+11"
APPS = ("entry_app", "admin_app", "dashboard_app")
PACKAGE_IDS = {
    "entry_app": "com.smartmeters.entry_app",
    "admin_app": "com.smartmeters.admin_app",
    "dashboard_app": "com.smartmeters.dashboard_app",
}
OPERATIONAL_TABLES = (
    "organizations",
    "zones",
    "sites",
    "site_tanks",
    "meters",
    "meter_readings",
)
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def top_level_sql(sql: str) -> str:
    """Exclude stored routine bodies while keeping migration-time executable SQL.

    INSERT statements inside CREATE FUNCTION/PROCEDURE define future runtime
    behavior and are not seed data. DO blocks execute during migration and are
    intentionally retained so any operational inserts inside them are caught.
    """
    dollar = re.compile(r"(?P<tag>\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$)")
    out: list[str] = []
    cursor = 0

    while True:
        start = dollar.search(sql, cursor)
        if start is None:
            out.append(sql[cursor:])
            break

        tag = start.group("tag")
        close = sql.find(tag, start.end())
        if close < 0:
            out.append(sql[cursor:])
            break

        end = close + len(tag)
        out.append(sql[cursor:start.start()])

        prefix = sql[max(0, start.start() - 2000):start.start()]
        statement = prefix[prefix.rfind(";") + 1:].lower()
        is_routine_body = (
            "create" in statement
            and (
                " function " in f" {statement} "
                or " procedure " in f" {statement} "
            )
            and re.search(r"\bas\s*$", statement) is not None
        )

        if is_routine_body:
            out.append(" ")
        else:
            out.append(sql[start.end():close])
        cursor = end

    cleaned = "".join(out)
    cleaned = re.sub(r"/\*.*?\*/", " ", cleaned, flags=re.DOTALL)
    cleaned = re.sub(r"--[^\n]*", " ", cleaned)
    cleaned = re.sub(r"'(?:''|[^'])*'", "''", cleaned, flags=re.DOTALL)
    return cleaned


for app in APPS:
    pubspec = ROOT / "apps" / app / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")
    match = re.search(r"(?m)^version:\s*(\S+)", text)
    require(match is not None, f"{app}: version is missing")
    if match is not None:
        require(
            match.group(1) == EXPECTED_VERSION,
            f"{app}: expected {EXPECTED_VERSION}, found {match.group(1)}",
        )

    gradle = ROOT / "apps" / app / "android" / "app" / "build.gradle.kts"
    gradle_text = gradle.read_text(encoding="utf-8")
    package_id = PACKAGE_IDS[app]
    require(
        f'applicationId = "{package_id}"' in gradle_text,
        f"{app}: unexpected Android applicationId",
    )
    require(
        "Release signing requires key.properties" in gradle_text,
        f"{app}: release signing is not fail-closed",
    )

seed_dir = ROOT / "supabase" / "seed"
seed_files = sorted(seed_dir.glob("*.sql")) if seed_dir.exists() else []
require(
    not seed_files,
    "zero-state release must not contain SQL files in supabase/seed: "
    + ", ".join(str(path.relative_to(ROOT)) for path in seed_files),
)
require(
    not (ROOT / "supabase" / "seed.sql").exists(),
    "supabase/seed.sql must be absent",
)

config = (ROOT / "supabase" / "config.toml").read_text(encoding="utf-8")
require(
    re.search(r"(?ms)^\[db\.seed\].*?^enabled\s*=\s*false\s*$", config)
    is not None,
    "supabase/config.toml must disable db.seed for the zero-state release",
)

insert_pattern = re.compile(
    r"insert\s+into\s+(?:public\.)?\"?("
    + "|".join(OPERATIONAL_TABLES)
    + r")\"?\b",
    flags=re.IGNORECASE | re.MULTILINE,
)
migration_name_pattern = re.compile(r"^(\d+)_([a-z0-9_]+)\.sql$")
seen_versions: dict[str, Path] = {}

for migration in sorted((ROOT / "supabase" / "migrations").glob("*.sql")):
    name_match = migration_name_pattern.match(migration.name)
    require(name_match is not None, f"invalid migration filename: {migration.name}")
    if name_match is not None:
        version = name_match.group(1)
        previous = seen_versions.get(version)
        require(
            previous is None,
            (
                f"duplicate migration version {version}: "
                f"{previous.name if previous else ''}, {migration.name}"
            ),
        )
        seen_versions[version] = migration

    migration_sql = migration.read_text(encoding="utf-8")
    if match := insert_pattern.search(top_level_sql(migration_sql)):
        errors.append(
            f"{migration.relative_to(ROOT)} seeds operational table {match.group(1)}"
        )

app_env = (
    ROOT / "packages" / "smart_meters_core" / "lib" / "config" / "app_env.dart"
).read_text(encoding="utf-8")
require(
    "defaultValue: 'production'" in app_env,
    "AppEnv must default to production for release builds",
)
require(
    "showDemoSiteUx => current.isStaging" in app_env,
    "demo site UX must be staging-only",
)

for workflow in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
    text = workflow.read_text(encoding="utf-8").lower()
    for forbidden in (
        "generate_demo_data.py",
        "import_demo_reports.py",
        "extract_demo_historical_xlsx.py",
        "001_seed_demo_site.sql",
    ):
        require(
            forbidden not in text,
            f"{workflow.relative_to(ROOT)} references demo tooling: {forbidden}",
        )

if errors:
    print("ZERO_STATE_RELEASE=FAIL", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)

print("ZERO_STATE_RELEASE=PASS")
print(f"VERSION={EXPECTED_VERSION}")
print("OPERATIONAL_SEEDS=0")
print("DEMO_RELEASE_REFERENCES=0")
