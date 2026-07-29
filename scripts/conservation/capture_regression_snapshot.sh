#!/usr/bin/env bash
# Capture Staging regression snapshot (counts) as JSON + Markdown.
# Usage: ./scripts/conservation/capture_regression_snapshot.sh [label]
# Requires: npx supabase linked to Staging.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

LABEL="${1:-manual}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$ROOT/docs/regression"
mkdir -p "$OUT_DIR"
JSON_OUT="$OUT_DIR/snapshot_${LABEL}_${STAMP}.json"
MD_OUT="$OUT_DIR/REGRESSION_${LABEL}_${STAMP}.md"

RAW="$(mktemp)"
npx supabase db query --linked "
select json_build_object(
  'label', '${LABEL}',
  'captured_at', now(),
  'git_head', '$(git rev-parse HEAD 2>/dev/null || echo unknown)',
  'git_branch', '$(git branch --show-current 2>/dev/null || echo unknown)',
  'organizations', (select count(*)::int from public.organizations),
  'zones', (select count(*)::int from public.zones),
  'sites', (select count(*)::int from public.sites),
  'meters', (select count(*)::int from public.meters),
  'meters_physical', (select count(*)::int from public.meters where meter_kind = 'physical'),
  'meters_virtual', (select count(*)::int from public.meters where meter_kind = 'virtual'),
  'meter_readings', (select count(*)::int from public.meter_readings),
  'reading_photos', (select count(*)::int from public.meter_readings where image_url is not null and length(trim(image_url)) > 0),
  'profiles', (select count(*)::int from public.profiles),
  'profiles_by_role', (select coalesce(json_object_agg(role, c), '{}'::json) from (select role::text as role, count(*)::int as c from public.profiles group by role) s),
  'profiles_by_approval', (select coalesce(json_object_agg(approval_status, c), '{}'::json) from (select approval_status::text as approval_status, count(*)::int as c from public.profiles group by approval_status) s),
  'user_site_access', (select count(*)::int from public.user_site_access),
  'cop_groups', (select count(*)::int from public.cop_groups),
  'cop_btu_links', (select count(*)::int from public.cop_group_btu_meters),
  'cop_elec_links', (select count(*)::int from public.cop_group_electricity_meters),
  'migration_count', (select count(*)::int from supabase_migrations.schema_migrations),
  'migration_max', (select max(version) from supabase_migrations.schema_migrations),
  'storage_buckets', (select coalesce(json_agg(json_build_object('id', id, 'name', name)), '[]'::json) from storage.buckets)
) as snapshot;
" >"$RAW"

python3 - "$RAW" "$JSON_OUT" "$MD_OUT" <<'PY'
import json, re, sys
raw_path, json_out, md_out = sys.argv[1:4]
text = open(raw_path, encoding='utf-8').read()
# Extract snapshot object from CLI JSON wrapper
m = re.search(r'"snapshot"\s*:\s*(\{.*?\})\s*\}\s*\]\s*,', text, re.S)
if not m:
    # fallback: find first { after snapshot
    idx = text.find('"snapshot"')
    if idx < 0:
        raise SystemExit('Could not parse snapshot from CLI output')
    start = text.find('{', idx)
    # naive brace match
    depth = 0
    end = None
    for i, ch in enumerate(text[start:], start):
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    snap = json.loads(text[start:end])
else:
    snap = json.loads(m.group(1))

open(json_out, 'w', encoding='utf-8').write(json.dumps(snap, indent=2, ensure_ascii=False) + '\n')

keys = [
    'organizations', 'zones', 'sites', 'meters', 'meters_physical', 'meters_virtual',
    'meter_readings', 'reading_photos', 'profiles', 'user_site_access',
    'cop_groups', 'cop_btu_links', 'cop_elec_links', 'migration_count', 'migration_max',
]
lines = [
    f"# Regression Snapshot — {snap.get('label')}",
    '',
    f"- Captured at: `{snap.get('captured_at')}`",
    f"- Git: `{snap.get('git_branch')}` @ `{snap.get('git_head')}`",
    '',
    '| Metric | Count |',
    '|--------|------:|',
]
for k in keys:
    lines.append(f"| {k} | {snap.get(k)} |")
lines += [
    '',
    '## Profiles by role',
    '```json',
    json.dumps(snap.get('profiles_by_role'), indent=2, ensure_ascii=False),
    '```',
    '',
    '## Profiles by approval',
    '```json',
    json.dumps(snap.get('profiles_by_approval'), indent=2, ensure_ascii=False),
    '```',
    '',
    '## Storage buckets',
    '```json',
    json.dumps(snap.get('storage_buckets'), indent=2, ensure_ascii=False),
    '```',
    '',
    f'JSON: `{json_out}`',
    '',
]
open(md_out, 'w', encoding='utf-8').write('\n'.join(lines))
print(json_out)
print(md_out)
PY

# Maintain stable pointer for baseline
if [[ "$LABEL" == "BASELINE" ]]; then
  cp "$JSON_OUT" "$OUT_DIR/REGRESSION_BASELINE_LATEST.json"
  cp "$MD_OUT" "$OUT_DIR/REGRESSION_BASELINE_LATEST.md"
fi

echo "Wrote $JSON_OUT"
echo "Wrote $MD_OUT"
