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
    "sites",
    "meters",
    "meter_readings",
)
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


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
require(not (ROOT / "supabase" / "seed.sql").exists(), "supabase/seed.sql must be absent")

insert_pattern = re.compile(
    r"insert\s+into\s+(?:public\.)?(?:\"?)("
    + "|".join(OPERATIONAL_TABLES)
    + r")(?:\"?)\b",
    flags=re.IGNORECASE | re.MULTILINE,
)
for migration in sorted((ROOT / "supabase" / "migrations").glob("*.sql")):
    text = migration.read_text(encoding="utf-8")
    if match := insert_pattern.search(text):
        errors.append(
            f"{migration.relative_to(ROOT)} seeds operational table {match.group(1)}"
        )

app_env = (ROOT / "packages" / "smart_meters_core" / "lib" / "config" / "app_env.dart").read_text(encoding="utf-8")
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
