#!/usr/bin/env python3
"""Apply CHW→GJ reclassify + COP wiring on Staging via PostgREST.

Requires migrations 016–017 already applied (gj enum + admin_reclassify_meter + gj unit).

Usage (from repo root, with .env.local loaded):
  python3 scripts/staging_chw_gj_cop_wiring.py
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SITE = "22222222-2222-4222-8222-222222222222"
COP = "44444444-4444-4444-8444-444444444444"
BTU_CAT = "c1111111-1111-4111-8111-111111111103"
GJ_UNIT = "e1111111-1111-4111-8111-111111111305"
BTU_SRC = "b1111111-1111-4111-8111-111111111301"  # chilled_water under BTU

CHW = {
    "CHW-LOOP-1": (
        "CHW-Loop 1 (Energy GJ)",
        "حلقة تبريد 1 — طاقة (جيجاجول)",
    ),
    "CHW-LOOP-2": (
        "CHW-Loop 2 (Energy GJ)",
        "حلقة تبريد 2 — طاقة (جيجاجول)",
    ),
    "CHW-LOOP-3": (
        "CHW-Loop 3 (Energy GJ)",
        "حلقة تبريد 3 — طاقة (جيجاجول)",
    ),
}
ELEC = ["1256361", "1256362"]  # LVP-4, LVP-5


def load_env() -> None:
    env_path = ROOT / ".env.local"
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def api(method: str, path: str, token: str, body=None):
    url = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_ANON_KEY"]
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(f"{url}{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:800]


def auth() -> str:
    st, payload = api(
        "POST",
        "/auth/v1/token?grant_type=password",
        "",
        {
            "email": os.environ.get(
                "STAGING_SUPER_ADMIN_EMAIL", "test-super-admin@validation.local"
            ),
            "password": os.environ.get(
                "STAGING_SUPER_ADMIN_PASSWORD", "ValidationTest1!"
            ),
        },
    )
    # auth endpoint doesn't need user bearer; pass anon via apikey only
    url = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_ANON_KEY"]
    body = json.dumps(
        {
            "email": os.environ.get(
                "STAGING_SUPER_ADMIN_EMAIL", "test-super-admin@validation.local"
            ),
            "password": os.environ.get(
                "STAGING_SUPER_ADMIN_PASSWORD", "ValidationTest1!"
            ),
        }
    ).encode()
    req = urllib.request.Request(
        f"{url}/auth/v1/token?grant_type=password",
        data=body,
        headers={"apikey": key, "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)["access_token"]


def main() -> int:
    load_env()
    if "SUPABASE_URL" not in os.environ or "SUPABASE_ANON_KEY" not in os.environ:
        print("Missing SUPABASE_URL / SUPABASE_ANON_KEY", file=sys.stderr)
        return 1

    token = auth()

    # Ensure GJ unit exists (migration 016)
    st, units = api(
        "GET",
        f"/rest/v1/meter_units?id=eq.{GJ_UNIT}&select=id,code,unit_to_base_factor",
        token,
    )
    if st != 200 or not units:
        # try create via REST (works even before enum if category FK ok)
        st, created = api(
            "POST",
            "/rest/v1/meter_units",
            token,
            {
                "id": GJ_UNIT,
                "category_id": BTU_CAT,
                "code": "gj",
                "name_en": "GJ",
                "name_ar": "جيجاجول",
                "unit_to_base_factor": 277.777778,
                "is_base": False,
                "sort_order": 5,
                "is_active": True,
            },
        )
        print("ensure gj unit", st, created if st >= 400 else "ok")
        if st >= 400:
            print(
                "ERROR: Apply migrations 016+017 (gj enum + catalog) first.",
                file=sys.stderr,
            )
            return 2

    codes = list(CHW.keys()) + ELEC
    st, meters = api(
        "GET",
        f"/rest/v1/meters?site_id=eq.{SITE}&meter_code=in.({','.join(codes)})"
        f"&select=id,meter_code,category,unit,unit_to_base_factor,is_active",
        token,
    )
    if st != 200:
        print("list meters failed", st, meters, file=sys.stderr)
        return 1
    by_code = {m["meter_code"]: m for m in meters}
    for code in CHW:
        if code not in by_code:
            print(f"ERROR: missing {code}", file=sys.stderr)
            return 1
    for code in ELEC:
        if code not in by_code:
            print(f"ERROR: missing {code}", file=sys.stderr)
            return 1

    for code, (name_en, name_ar) in CHW.items():
        mid = by_code[code]["id"]
        st, res = api(
            "POST",
            "/rest/v1/rpc/admin_reclassify_meter",
            token,
            {
                "p_meter_id": mid,
                "p_category_id": BTU_CAT,
                "p_source_id": BTU_SRC,
                "p_unit_id": GJ_UNIT,
                "p_name_en": name_en,
                "p_name_ar": name_ar,
            },
        )
        print("reclassify", code, st, "ok" if st in (200, 204) else res)
        if st not in (200, 204):
            print(
                "ERROR: admin_reclassify_meter missing or failed — apply migration 017.",
                file=sys.stderr,
            )
            return 2
        api(
            "PATCH",
            f"/rest/v1/meters?id=eq.{mid}",
            token,
            {"is_active": True, "include_in_dashboard": True},
        )

    # COP group upsert
    api(
        "POST",
        "/rest/v1/cop_groups",
        token,
        {
            "id": COP,
            "site_id": SITE,
            "name_en": "Chiller Plant COP",
            "name_ar": "معامل أداء محطة التبريد",
            "description": (
                "3 CHW energy loops (GJ) ÷ electrical panels LVP-4 + LVP-5 (kWh) "
                "serving four chillers."
            ),
            "is_active": True,
        },
    )
    api(
        "PATCH",
        f"/rest/v1/cop_groups?id=eq.{COP}",
        token,
        {
            "description": (
                "3 CHW energy loops (GJ) ÷ electrical panels LVP-4 + LVP-5 (kWh) "
                "serving four chillers."
            ),
            "is_active": True,
        },
    )

    api("DELETE", f"/rest/v1/cop_group_btu_meters?cop_group_id=eq.{COP}", token)
    api("DELETE", f"/rest/v1/cop_group_electricity_meters?cop_group_id=eq.{COP}", token)

    for code in CHW:
        st, res = api(
            "POST",
            "/rest/v1/cop_group_btu_meters",
            token,
            {"cop_group_id": COP, "meter_id": by_code[code]["id"], "weight": 1},
        )
        print("cop btu", code, st, "ok" if st < 300 else res)

    for code in ELEC:
        st, res = api(
            "POST",
            "/rest/v1/cop_group_electricity_meters",
            token,
            {"cop_group_id": COP, "meter_id": by_code[code]["id"], "weight": 1},
        )
        print("cop elec", code, st, "ok" if st < 300 else res)

    # Verify
    st, final = api(
        "GET",
        f"/rest/v1/meters?site_id=eq.{SITE}&meter_code=in.({','.join(CHW.keys())})"
        f"&select=meter_code,category,unit,unit_to_base_factor,name_en",
        token,
    )
    print("final meters", final)
    st, btu_m = api(
        "GET",
        f"/rest/v1/cop_group_btu_meters?cop_group_id=eq.{COP}&select=meter_id",
        token,
    )
    st, el_m = api(
        "GET",
        f"/rest/v1/cop_group_electricity_meters?cop_group_id=eq.{COP}&select=meter_id",
        token,
    )
    print("cop members btu", len(btu_m or []), "elec", len(el_m or []))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
