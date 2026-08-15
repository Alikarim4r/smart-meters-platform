#!/usr/bin/env bash
# Compare a regression JSON snapshot to REGRESSION_BASELINE_LATEST.json
# Exit 1 on unexpected drift for protected metrics.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="${1:-$ROOT/docs/regression/REGRESSION_BASELINE_LATEST.json}"
CUR="${2:-}"

if [[ -z "$CUR" ]]; then
  echo "Usage: $0 <baseline.json> <current.json>" >&2
  exit 2
fi

python3 - "$BASE" "$CUR" <<'PY'
import json, sys
base = json.load(open(sys.argv[1], encoding='utf-8'))
cur = json.load(open(sys.argv[2], encoding='utf-8'))

# Protected metrics — any change is STOP unless explained
protected = [
    'organizations', 'zones', 'sites', 'meters', 'meters_physical', 'meters_virtual',
    'meter_readings', 'reading_photos', 'profiles', 'user_site_access',
    'cop_groups', 'cop_btu_links', 'cop_elec_links',
]

print('| Metric | Baseline | Current | Delta | Status |')
print('|--------|---------:|--------:|------:|--------|')
failed = False
for k in protected:
    b = base.get(k)
    c = cur.get(k)
    delta = None if b is None or c is None else (c - b)
    status = 'OK' if b == c else 'DRIFT'
    if status == 'DRIFT':
        failed = True
    print(f'| {k} | {b} | {c} | {delta} | {status} |')

# Informational
for k in ['migration_count', 'migration_max', 'profiles_by_role', 'profiles_by_approval']:
    print(f'INFO {k}: baseline={base.get(k)!r} current={cur.get(k)!r}')

if failed:
    print('RESULT: STOP — unexpected regression drift detected', file=sys.stderr)
    sys.exit(1)
print('RESULT: PASS — protected metrics unchanged')
PY
