#!/usr/bin/env python3
"""One-time idempotent import of MOEHE HQ meters and readings from consolidated CSVs.

Staging/admin use only — never embed service_role or import credentials in Flutter apps.

Usage:
  python3 scripts/import_moehe_hq_reports.py --dry-run
  python3 scripts/import_moehe_hq_reports.py --apply
  python3 scripts/import_moehe_hq_reports.py --apply \\
    --readings-csv imports/moehe_hq_reports/moehe_hq_readings_feb2020_may2026.csv \\
    --date-from 2020-02-01 --date-to 2026-05-31

Environment:
  SUPABASE_URL (required)
  SUPABASE_ANON_KEY (required)
  IMPORT_ADMIN_EMAIL (required)
  IMPORT_ADMIN_PASSWORD (required)
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
IMPORT_DIR = ROOT / "imports" / "moehe_hq_reports"
METERS_CSV = IMPORT_DIR / "moehe_hq_meters_from_reports.csv"
READINGS_CSV = IMPORT_DIR / "moehe_hq_readings_mar_apr_may_2026.csv"

SITE_NAME_HINTS = ("moehe hq", "permanent hq", "permanent headquarters")
PREFERRED_SITE_ID = "22222222-2222-4222-8222-222222222222"

# Extra water sources needed for Energy & Flow meters (stored under water category).
EXTRA_WATER_SOURCES = {
    "chilled_water": ("Chilled Water", "مياه مبردة"),
    "storm_water": ("Storm Water", "مياه أمطار"),
    "cooling_tower_blowdown": ("Cooling Tower Blowdown", "تصريف برج التبريد"),
}

SYSTEM_CATEGORY_IDS = {
    "water": "c1111111-1111-4111-8111-111111111101",
    "electricity": "c1111111-1111-4111-8111-111111111102",
    "fuel": "c1111111-1111-4111-8111-111111111104",
}


@dataclass
class ImportStats:
    catalog_categories_created: int = 0
    catalog_units_created: int = 0
    catalog_sources_created: int = 0
    meters_inserted: int = 0
    meters_updated: int = 0
    meters_skipped: int = 0
    readings_inserted: int = 0
    readings_skipped_same: int = 0
    readings_conflicts: int = 0
    readings_missing_meter: int = 0
    conflict_samples: list[str] = field(default_factory=list)
    flow_fallback_meters: int = 0


class SupabaseClient:
    def __init__(self, url: str, anon_key: str, token: str, user_id: str) -> None:
        self.url = url.rstrip("/")
        self.anon_key = anon_key
        self.token = token
        self.user_id = user_id

    def request(
        self,
        method: str,
        path: str,
        *,
        body: Any | None = None,
        prefer: str | None = None,
        accept_count: bool = False,
    ) -> tuple[int, Any, dict[str, str]]:
        headers = {
            "apikey": self.anon_key,
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }
        if prefer:
            headers["Prefer"] = prefer
        data = None
        if body is not None:
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(
            f"{self.url}/rest/v1/{path}",
            data=data,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(req) as resp:
                raw = resp.read().decode()
                payload = json.loads(raw) if raw else None
                return resp.status, payload, dict(resp.headers)
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode()
            raise RuntimeError(f"{method} {path} failed ({exc.code}): {detail}") from exc

    def get(self, path: str) -> Any:
        _, payload, _ = self.request("GET", path)
        return payload

    def post(self, path: str, body: Any, *, prefer: str | None = None) -> Any:
        _, payload, _ = self.request("POST", path, body=body, prefer=prefer)
        return payload

    def patch(self, path: str, body: Any) -> None:
        self.request("PATCH", path, body=body)

    def count(self, path: str) -> int:
        headers = {
            "apikey": self.anon_key,
            "Authorization": f"Bearer {self.token}",
            "Prefer": "count=exact",
        }
        req = urllib.request.Request(
            f"{self.url}/rest/v1/{path}",
            headers=headers,
            method="GET",
        )
        with urllib.request.urlopen(req) as resp:
            content_range = resp.headers.get("Content-Range", "")
        if "/" in content_range:
            total = content_range.split("/")[-1]
            if total.isdigit():
                return int(total)
        rows = self.get(path + "&limit=10000")
        return len(rows) if isinstance(rows, list) else 0


def sign_in(url: str, anon_key: str, email: str, password: str) -> tuple[str, str]:
    last_error: Exception | None = None
    for attempt in range(5):
        try:
            req = urllib.request.Request(
                f"{url.rstrip('/')}/auth/v1/token?grant_type=password",
                data=json.dumps({"email": email, "password": password}).encode(),
                headers={"apikey": anon_key, "Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=45) as resp:
                payload = json.load(resp)
            return payload["access_token"], payload["user"]["id"]
        except Exception as exc:
            last_error = exc
            time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"Auth failed after retries: {last_error}") from last_error


def parse_bool(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "y"}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def effective_category_code(row: dict[str, str]) -> str:
    code = row["category_code"].strip().lower()
    meter_code = row.get("meter_code", "").strip().upper()
    # CHW loops are cooling-energy meters (GJ), not water flow.
    if meter_code in {"CHW-LOOP-1", "CHW-LOOP-2", "CHW-LOOP-3"}:
        return "btu"
    if code == "flow":
        return row.get("fallback_category_code", "water").strip().lower() or "water"
    return code


def effective_unit_code(row: dict[str, str], category_code: str) -> str:
    meter_code = row.get("meter_code", "").strip().upper()
    if meter_code in {"CHW-LOOP-1", "CHW-LOOP-2", "CHW-LOOP-3"}:
        return "gj"
    unit_code = row["unit_code"].strip().lower()
    if category_code == "btu" and unit_code in {"m3", "flow"}:
        return "gj"
    return unit_code


def build_name_ar(row: dict[str, str], flow_fallback: bool) -> str:
    base = row["name_en"].strip() or row["meter_code"].strip()
    parts = [base]
    location = row.get("location", "").strip()
    if location:
        parts.append(location)
    meter_code = row.get("meter_code", "").strip().upper()
    if meter_code in {"CHW-LOOP-1", "CHW-LOOP-2", "CHW-LOOP-3"}:
        parts.append("Energy GJ (chiller loops)")
    elif flow_fallback:
        parts.append("Energy & Flow (imported as water)")
    notes = row.get("notes", "").strip()
    if notes:
        parts.append(notes[:120])
    return " | ".join(parts)[:500]


def build_reading_note(row: dict[str, str]) -> str:
    parts = [row.get("note", "").strip()]
    if row.get("category_code", "").strip().lower() == "flow":
        parts.append("Original meter category: flow (Energy & Flow)")
    trace = (
        f"import_source={row.get('source_file', '').strip()}; "
        f"sheet={row.get('source_sheet', '').strip()}; "
        f"row={row.get('source_row', '').strip()}"
    )
    parts.append(trace)
    return " | ".join(part for part in parts if part)


def resolve_target_site(client: SupabaseClient) -> dict[str, Any]:
    sites = client.get(
        "sites?select=id,name_en,name_ar,is_active&order=name_en"
    )
    matches = []
    for site in sites:
        label = f"{site['name_en']} {site.get('name_ar', '')}".lower()
        if any(hint in label for hint in SITE_NAME_HINTS):
            matches.append(site)

    if not matches:
        raise RuntimeError("No MOEHE HQ / Permanent HQ site found")

    preferred = [s for s in matches if s["id"] == PREFERRED_SITE_ID]
    if preferred:
        return preferred[0]

    if len(matches) == 1:
        return matches[0]

    choices = "\n".join(f"- {s['id']}: {s['name_en']}" for s in matches)
    raise RuntimeError(
        "Multiple possible MOEHE HQ sites found; resolve manually:\n" + choices
    )


def load_catalog_maps(client: SupabaseClient) -> tuple[dict[str, str], dict[str, dict[str, str]], dict[str, dict[str, str]]]:
    categories = {
        row["code"]: row["id"]
        for row in client.get("meter_categories?select=id,code")
    }
    units: dict[str, dict[str, str]] = {}
    for row in client.get("meter_units?select=id,code,category_id"):
        cat_code = next(code for code, cid in categories.items() if cid == row["category_id"])
        units.setdefault(cat_code, {})[row["code"]] = row["id"]

    sources: dict[str, dict[str, str]] = {}
    for row in client.get("meter_sources?select=id,code,category_id"):
        cat_code = next(code for code, cid in categories.items() if cid == row["category_id"])
        sources.setdefault(cat_code, {})[row["code"]] = row["id"]

    return categories, units, sources


def ensure_catalog(
    client: SupabaseClient,
    stats: ImportStats,
    *,
    apply: bool,
) -> tuple[dict[str, str], dict[str, dict[str, str]], dict[str, dict[str, str]]]:
    categories, units, sources = load_catalog_maps(client)
    water_id = categories.get("water") or SYSTEM_CATEGORY_IDS["water"]

    for code, (name_en, name_ar) in EXTRA_WATER_SOURCES.items():
        if code in sources.get("water", {}):
            continue
        stats.catalog_sources_created += 1
        if apply:
            created = client.post(
                "meter_sources",
                {
                    "category_id": water_id,
                    "code": code,
                    "name_en": name_en,
                    "name_ar": name_ar,
                    "sort_order": 50,
                    "is_active": True,
                },
                prefer="return=representation",
            )
            sources.setdefault("water", {})[code] = created[0]["id"]
        else:
            sources.setdefault("water", {})[code] = f"dry-run-source-{code}"

    if apply:
        categories, units, sources = load_catalog_maps(client)
    return categories, units, sources


def resolve_catalog_ids(
    row: dict[str, str],
    categories: dict[str, str],
    units: dict[str, dict[str, str]],
    sources: dict[str, dict[str, str]],
) -> tuple[str, str, str, str, bool]:
    meter_code = row.get("meter_code", "").strip().upper()
    raw_cat = row["category_code"].strip().lower()
    flow_fallback = raw_cat == "flow" and meter_code not in {
        "CHW-LOOP-1",
        "CHW-LOOP-2",
        "CHW-LOOP-3",
    }
    category_code = effective_category_code(row)
    source_code = row["source_code"].strip().lower()
    if category_code == "btu" and source_code in {
        "cooling_tower_blowdown",
        "storm_water",
    }:
        source_code = "chilled_water"
    unit_code = effective_unit_code(row, category_code)

    if category_code not in categories:
        raise RuntimeError(f"Unknown category_code={category_code}")
    if unit_code not in units.get(category_code, {}):
        raise RuntimeError(
            f"Unknown unit_code={unit_code} for category={category_code}"
        )

    source_map = sources.get(category_code, {})
    if source_code not in source_map:
        if category_code == "water" and source_code in EXTRA_WATER_SOURCES:
            raise RuntimeError(f"Missing water source {source_code} — run catalog ensure first")
        if "other" not in source_map:
            raise RuntimeError(f"Missing fallback source 'other' for category={category_code}")
        source_code = "other"

    return (
        categories[category_code],
        source_map[source_code],
        units[category_code][unit_code],
        category_code,
        flow_fallback,
    )


def meter_has_readings(client: SupabaseClient, meter_id: str) -> bool:
    return client.count(f"meter_readings?meter_id=eq.{meter_id}&select=id") > 0


def upsert_meters(
    client: SupabaseClient,
    site: dict[str, Any],
    meter_rows: list[dict[str, str]],
    categories: dict[str, str],
    units: dict[str, dict[str, str]],
    sources: dict[str, dict[str, str]],
    stats: ImportStats,
    *,
    apply: bool,
) -> dict[str, str]:
    existing_rows = client.get(
        f"meters?site_id=eq.{site['id']}&select=id,meter_code,name_en,category,source,unit,category_id,source_id,unit_id"
    )
    existing = {row["meter_code"]: row for row in existing_rows}
    code_to_id: dict[str, str] = {row["meter_code"]: row["id"] for row in existing_rows}

    sort_order = 100
    for row in meter_rows:
        meter_code = row["meter_code"].strip()
        if not meter_code:
            stats.meters_skipped += 1
            continue

        category_id, source_id, unit_id, category_code, flow_fallback = resolve_catalog_ids(
            row, categories, units, sources
        )
        if flow_fallback:
            stats.flow_fallback_meters += 1

        payload = {
            "site_id": site["id"],
            "meter_code": meter_code,
            "name_en": row["name_en"].strip() or meter_code,
            "name_ar": build_name_ar(row, flow_fallback),
            "category_id": category_id,
            "source_id": source_id,
            "unit_id": unit_id,
            "level": row.get("level", "main").strip().lower() or "main",
            "include_in_dashboard": parse_bool(row.get("include_in_dashboard", "true")),
            "is_active": parse_bool(row.get("is_active", "true")),
            "meter_kind": "physical",
            "calculation_type": "direct_reading",
            "sort_order": sort_order,
        }
        sort_order += 1

        if meter_code in existing:
            current = existing[meter_code]
            update_body: dict[str, Any] = {
                "name_en": payload["name_en"],
                "name_ar": payload["name_ar"],
                "include_in_dashboard": payload["include_in_dashboard"],
                "is_active": payload["is_active"],
            }
            if not meter_has_readings(client, current["id"]):
                update_body.update(
                    {
                        "category_id": category_id,
                        "source_id": source_id,
                        "unit_id": unit_id,
                    }
                )
            changed = any(
                str(current.get(key)) != str(value)
                for key, value in update_body.items()
            )
            if changed:
                stats.meters_updated += 1
                if apply:
                    client.patch(
                        f"meters?site_id=eq.{site['id']}&meter_code=eq.{urllib.parse.quote(meter_code, safe='')}",
                        update_body,
                    )
            else:
                stats.meters_skipped += 1
            code_to_id[meter_code] = current["id"]
            continue

        stats.meters_inserted += 1
        if apply:
            created = client.post("meters", payload, prefer="return=representation")
            code_to_id[meter_code] = created[0]["id"]
        else:
            code_to_id[meter_code] = f"dry-run-{meter_code}"

    if apply:
        refreshed = client.get(
            f"meters?site_id=eq.{site['id']}&select=id,meter_code"
        )
        code_to_id = {row["meter_code"]: row["id"] for row in refreshed}

    return code_to_id


def load_existing_readings(
    client: SupabaseClient,
    site_id: str,
    *,
    date_from: str = "2020-02-01",
    date_to: str = "2026-05-31",
) -> dict[tuple[str, str], float]:
    existing: dict[tuple[str, str], float] = {}
    offset = 0
    page_size = 1000
    while True:
        rows = client.get(
            f"meter_readings?site_id=eq.{site_id}"
            "&select=meter_id,reading_date,raw_value,meters(meter_code)"
            f"&reading_date=gte.{date_from}&reading_date=lte.{date_to}"
            f"&order=reading_date.asc&limit={page_size}&offset={offset}"
        )
        if not rows:
            break
        for row in rows:
            meter_code = row.get("meters", {}).get("meter_code")
            if meter_code:
                existing[(meter_code, row["reading_date"])] = float(row["raw_value"])
            existing[(row["meter_id"], row["reading_date"])] = float(row["raw_value"])
        if len(rows) < page_size:
            break
        offset += page_size
    return existing


def import_readings(
    client: SupabaseClient,
    site: dict[str, Any],
    reading_rows: list[dict[str, str]],
    meter_code_to_id: dict[str, str],
    stats: ImportStats,
    *,
    apply: bool,
    date_from: str = "2020-02-01",
    date_to: str = "2026-05-31",
) -> None:
    existing = load_existing_readings(
        client, site["id"], date_from=date_from, date_to=date_to
    )
    batch: list[dict[str, Any]] = []

    def flush_batch() -> None:
        nonlocal batch
        if not batch or not apply:
            batch = []
            return
        client.post("meter_readings", batch, prefer="return=minimal")
        batch = []

    for row in reading_rows:
        meter_code = row["meter_code"].strip()
        meter_id = meter_code_to_id.get(meter_code)
        if not meter_id:
            stats.readings_missing_meter += 1
            continue

        reading_date = row["reading_date"].strip()
        if reading_date < date_from or reading_date > date_to:
            continue
        raw_value = float(row["raw_value"])
        existing_key = (meter_code, reading_date)
        if existing_key in existing:
            if abs(existing[existing_key] - raw_value) < 0.0001:
                stats.readings_skipped_same += 1
            else:
                stats.readings_conflicts += 1
                if len(stats.conflict_samples) < 20:
                    stats.conflict_samples.append(
                        f"{meter_code} {reading_date}: db={existing[existing_key]} csv={raw_value}"
                    )
            continue

        stats.readings_inserted += 1
        if meter_id.startswith("dry-run-"):
            continue

        note = build_reading_note(row)
        batch.append(
            {
                "site_id": site["id"],
                "meter_id": meter_id,
                "reading_date": reading_date,
                "raw_value": raw_value,
                "normalized_value": raw_value,
                "note": note,
                "entered_by": client.user_id,
            }
        )
        existing[existing_key] = raw_value

        if len(batch) >= 200:
            flush_batch()

    flush_batch()


def validate_import(
    client: SupabaseClient,
    site_id: str,
    *,
    date_from: str = "2020-02-01",
    date_to: str = "2026-05-31",
) -> dict[str, Any]:
    meters = client.count(f"meters?site_id=eq.{site_id}&select=id")
    readings_window = client.count(
        f"meter_readings?site_id=eq.{site_id}"
        f"&reading_date=gte.{date_from}&reading_date=lte.{date_to}&select=id"
    )
    readings_mar_may = client.count(
        f"meter_readings?site_id=eq.{site_id}"
        "&reading_date=gte.2026-03-01&reading_date=lte.2026-05-31&select=id"
    )
    sample = client.get(
        f"meter_readings?site_id=eq.{site_id}"
        f"&reading_date=gte.{date_from}&reading_date=lte.{date_to}"
        "&select=reading_date,raw_value,meters(meter_code)"
        "&order=reading_date.asc&limit=3"
    )
    sample_recent = client.get(
        f"meter_readings?site_id=eq.{site_id}"
        f"&reading_date=gte.{date_from}&reading_date=lte.{date_to}"
        "&select=reading_date,raw_value,meters(meter_code)"
        "&order=reading_date.desc&limit=3"
    )
    return {
        "meters_total": meters,
        "readings_in_window": readings_window,
        "readings_mar_may_2026": readings_mar_may,
        "window": {"from": date_from, "to": date_to},
        "sample_earliest": sample,
        "sample_latest": sample_recent,
    }


def print_report(
    site: dict[str, Any],
    stats: ImportStats,
    *,
    mode: str,
    validation: dict[str, Any] | None = None,
) -> None:
    print("\n" + "=" * 72)
    print(f"MOEHE HQ IMPORT — {mode}")
    print("=" * 72)
    print(f"Target site: {site['name_en']} ({site['id']})")
    print(f"Flow fallback decision: CHW-LOOP-* → btu/gj; other flow → water")
    print(f"Flow meters using water fallback: {stats.flow_fallback_meters}")
    print("-" * 72)
    print(f"Catalog sources created: {stats.catalog_sources_created}")
    print(f"Catalog categories created: {stats.catalog_categories_created}")
    print(f"Catalog units created: {stats.catalog_units_created}")
    print(f"Meters inserted: {stats.meters_inserted}")
    print(f"Meters updated: {stats.meters_updated}")
    print(f"Meters skipped (unchanged): {stats.meters_skipped}")
    print(f"Readings inserted: {stats.readings_inserted}")
    print(f"Readings skipped (same value): {stats.readings_skipped_same}")
    print(f"Readings conflicts (not overwritten): {stats.readings_conflicts}")
    print(f"Readings missing meter: {stats.readings_missing_meter}")
    if stats.conflict_samples:
        print("Conflict samples:")
        for sample in stats.conflict_samples:
            print(f"  - {sample}")
    if validation:
        print("-" * 72)
        print("Post-import validation:")
        print(json.dumps(validation, indent=2))
    print("=" * 72 + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--dry-run", action="store_true", help="Plan import without writing")
    group.add_argument("--apply", action="store_true", help="Execute import")
    parser.add_argument(
        "--meters-csv",
        type=Path,
        default=METERS_CSV,
        help=f"Meters inventory CSV (default: {METERS_CSV.name})",
    )
    parser.add_argument(
        "--readings-csv",
        type=Path,
        default=READINGS_CSV,
        help=f"Readings CSV (default: {READINGS_CSV.name})",
    )
    parser.add_argument(
        "--date-from",
        default="2020-02-01",
        help="Inclusive lower bound for conflict checks / import window",
    )
    parser.add_argument(
        "--date-to",
        default="2026-05-31",
        help="Inclusive upper bound for conflict checks / import window",
    )
    args = parser.parse_args()

    url = os.environ.get("SUPABASE_URL", "").strip()
    anon_key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    email = os.environ.get("IMPORT_ADMIN_EMAIL", "").strip()
    password = os.environ.get("IMPORT_ADMIN_PASSWORD", "").strip()

    missing = [
        name
        for name, value in (
            ("SUPABASE_URL", url),
            ("SUPABASE_ANON_KEY", anon_key),
            ("IMPORT_ADMIN_EMAIL", email),
            ("IMPORT_ADMIN_PASSWORD", password),
        )
        if not value
    ]
    if missing:
        print(
            "Missing required env: " + ", ".join(missing),
            file=sys.stderr,
        )
        return 1

    meters_csv: Path = args.meters_csv
    readings_csv: Path = args.readings_csv
    for path in (meters_csv, readings_csv):
        if not path.exists():
            print(f"Missing CSV: {path}", file=sys.stderr)
            return 1

    token, user_id = sign_in(url, anon_key, email, password)
    client = SupabaseClient(url, anon_key, token, user_id)
    stats = ImportStats()

    site = resolve_target_site(client)
    meter_rows = read_csv(meters_csv)
    reading_rows = read_csv(readings_csv)

    print(
        f"Loaded {len(meter_rows)} meters and {len(reading_rows)} readings from CSV"
    )
    print(f"Import window: {args.date_from} … {args.date_to}")

    categories, units, sources = ensure_catalog(
        client, stats, apply=args.apply
    )
    meter_code_to_id = upsert_meters(
        client,
        site,
        meter_rows,
        categories,
        units,
        sources,
        stats,
        apply=args.apply,
    )
    import_readings(
        client,
        site,
        reading_rows,
        meter_code_to_id,
        stats,
        apply=args.apply,
        date_from=args.date_from,
        date_to=args.date_to,
    )

    validation = (
        validate_import(
            client,
            site["id"],
            date_from=args.date_from,
            date_to=args.date_to,
        )
        if args.apply
        else None
    )
    print_report(
        site,
        stats,
        mode="APPLY" if args.apply else "DRY-RUN",
        validation=validation,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())