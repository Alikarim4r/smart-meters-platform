#!/usr/bin/env python3
"""Prune MOEHE HQ staging readings to a limited real-data window.

Keeps readings with reading_date >= KEEP_FROM (default 2026-01-01) for the
MOEHE HQ site. Deletes older rows in monthly batches via the authenticated
super_admin session (RLS meter_readings_delete_admin).

Usage:
  export SUPABASE_URL=https://YOUR_PROJECT.supabase.co
  export SUPABASE_ANON_KEY=<anon>
  export STAGING_SUPER_EMAIL=<admin-email>
  export STAGING_SUPER_PASSWORD=<admin-password>
  python3 scripts/prune_staging_moehe_limited.py [--dry-run] [--keep-from YYYY-MM-DD]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import date

MOEHE_SITE_ID = "22222222-2222-4222-8222-222222222222"
DEFAULT_KEEP_FROM = date(2026, 1, 1)
HISTORY_START = date(2020, 1, 1)


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required env: {name}")
    return value


def request(
    url: str,
    key: str,
    path: str,
    *,
    token: str | None = None,
    method: str = "GET",
    body: dict | None = None,
    prefer: str | None = None,
    timeout: float = 120,
):
    headers = {
        "apikey": key,
        "Content-Type": "application/json",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if prefer:
        headers["Prefer"] = prefer
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        f"{url}{path}", data=data, headers=headers, method=method
    )
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            payload = json.loads(raw) if raw else None
            return resp.status, time.time() - t0, payload, dict(resp.headers)
    except urllib.error.HTTPError as e:
        detail = e.read().decode()[:400]
        raise RuntimeError(f"{method} {path} -> HTTP {e.code}: {detail}") from e


def iter_month_bounds(start: date, end_exclusive: date):
    cursor = date(start.year, start.month, 1)
    while cursor < end_exclusive:
        nxt = (
            date(cursor.year + 1, 1, 1)
            if cursor.month == 12
            else date(cursor.year, cursor.month + 1, 1)
        )
        upper = min(nxt, end_exclusive)
        yield cursor.isoformat(), upper.isoformat()
        cursor = nxt


def count_readings(url: str, key: str, token: str, site_id: str, query: str) -> int:
    path = f"/rest/v1/meter_readings?select=id&site_id=eq.{site_id}&{query}&limit=1"
    _, _, _, headers = request(
        url, key, path, token=token, prefer="count=exact", timeout=90
    )
    cr = headers.get("Content-Range") or headers.get("content-range") or ""
    if "/" not in cr:
        return -1
    total = cr.split("/")[-1]
    return int(total) if total.isdigit() else -1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--keep-from",
        default=DEFAULT_KEEP_FROM.isoformat(),
        help="Keep readings on/after this date (YYYY-MM-DD)",
    )
    args = parser.parse_args()
    keep_from = date.fromisoformat(args.keep_from)

    url = env("SUPABASE_URL").rstrip("/")
    key = env("SUPABASE_ANON_KEY")
    email = env("STAGING_SUPER_EMAIL")
    password = env("STAGING_SUPER_PASSWORD")

    _, _, tok, _ = request(
        url,
        key,
        "/auth/v1/token?grant_type=password",
        method="POST",
        body={"email": email, "password": password},
    )
    token = tok["access_token"]

    before_all = count_readings(url, key, token, MOEHE_SITE_ID, "order=id")
    before_keep = count_readings(
        url,
        key,
        token,
        MOEHE_SITE_ID,
        f"reading_date=gte.{keep_from.isoformat()}",
    )
    before_drop = count_readings(
        url,
        key,
        token,
        MOEHE_SITE_ID,
        f"reading_date=lt.{keep_from.isoformat()}",
    )
    print(
        f"MOEHE site {MOEHE_SITE_ID}\n"
        f"  total={before_all} keep>={keep_from}={before_keep} "
        f"drop<{keep_from}={before_drop}"
    )
    if before_drop == 0:
        print("Nothing to prune.")
        return 0
    if args.dry_run:
        print("Dry run only — no deletes.")
        return 0

    deleted = 0
    for gte, lt in iter_month_bounds(HISTORY_START, keep_from):
        path = (
            f"/rest/v1/meter_readings?site_id=eq.{MOEHE_SITE_ID}"
            f"&reading_date=gte.{gte}&reading_date=lt.{lt}"
        )
        try:
            status, elapsed, payload, headers = request(
                url,
                key,
                path,
                token=token,
                method="DELETE",
                prefer="return=representation,count=exact",
                timeout=180,
            )
        except RuntimeError as e:
            print(f"  FAIL {gte}..{lt}: {e}")
            return 1
        n = len(payload) if isinstance(payload, list) else 0
        cr = headers.get("Content-Range") or headers.get("content-range")
        deleted += n
        if n:
            print(
                f"  deleted {gte}..{lt}: rows={n} status={status} "
                f"{elapsed:.1f}s cr={cr}"
            )
        else:
            print(f"  empty {gte}..{lt} ({elapsed:.1f}s)")

    after_all = count_readings(url, key, token, MOEHE_SITE_ID, "order=id")
    after_drop = count_readings(
        url,
        key,
        token,
        MOEHE_SITE_ID,
        f"reading_date=lt.{keep_from.isoformat()}",
    )
    print(
        f"Done. deleted_reported≈{deleted} remaining_total={after_all} "
        f"still_before_keep={after_drop}"
    )
    if after_drop != 0:
        print("WARNING: rows remain before keep-from.", file=sys.stderr)
        return 2
    if after_all != before_keep:
        print(
            f"WARNING: expected remaining={before_keep}, got {after_all}",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
