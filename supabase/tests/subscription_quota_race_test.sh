#!/usr/bin/env bash
# Concurrency regression for subscription quotas (max_sites / max_meters).
# Launches N parallel transactions that each try to create one site (then one
# meter) while the org has room for exactly one. With atomic enforcement, at
# most max_* rows may survive. Commits real rows, so it cleans up after itself.
#
# DISPOSABLE/LOCAL DATABASES ONLY. Requires an explicit connection URL:
#   SUBSCRIPTION_GATE_DB_URL=postgresql://postgres:postgres@127.0.0.1:55422/postgres \
#     supabase/tests/subscription_quota_race_test.sh
set -euo pipefail

DB_URL="${SUBSCRIPTION_GATE_DB_URL:?set SUBSCRIPTION_GATE_DB_URL to a disposable local database}"
case "$DB_URL" in
  *@127.0.0.1:*|*@localhost:*) ;;
  *) echo "refusing: SUBSCRIPTION_GATE_DB_URL must point at 127.0.0.1/localhost" >&2; exit 2 ;;
esac
case "$DB_URL" in
  *:54322/*) echo "refusing: port 54322 is reserved for another local stack" >&2; exit 2 ;;
esac

WORKERS="${RACE_WORKERS:-8}"
PSQL=(psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1)
ORG="$(uuidgen | tr 'A-Z' 'a-z')"
SITE="$(uuidgen | tr 'A-Z' 'a-z')"

cleanup() {
  "${PSQL[@]}" -c "
    delete from public.meters where site_id in (select id from public.sites where organization_id = '$ORG');
    delete from public.sites where organization_id = '$ORG';
    delete from public.organization_subscriptions where organization_id = '$ORG';
    delete from public.organizations where id = '$ORG';" >/dev/null
}
trap cleanup EXIT

"${PSQL[@]}" -c "
  insert into public.organizations (id, name_en, name_ar) values ('$ORG', 'race-org', 'race-org');
  insert into public.organization_subscriptions
    (organization_id, plan, status, current_period_end, max_users, max_sites, max_meters, features)
  values ('$ORG', 'starter', 'active', now() + interval '1 day', 10, 1, 1, '{}')
  on conflict (organization_id) do update set plan = 'starter', status = 'active',
    current_period_end = now() + interval '1 day', grace_period_end = null,
    max_sites = 1, max_meters = 1;" >/dev/null

race() { # $1 = label, $2 = SQL executed by every worker
  local pids=() i
  for i in $(seq 1 "$WORKERS"); do
    "${PSQL[@]}" -c "begin; ${2//@I@/$i}; select pg_sleep(0.5); commit;" >/dev/null 2>&1 &
    pids+=($!)
  done
  for i in "${pids[@]}"; do wait "$i" || true; done
}

# Sites: room for exactly 1.
race sites "insert into public.sites (organization_id, name_en, name_ar) values ('$ORG', 'race-site-@I@', 'race-site-@I@')"
SITES="$("${PSQL[@]}" -c "select count(*) from public.sites where organization_id = '$ORG' and is_active")"

# Meters: deactivate the raced sites, add one inactive host site, room for exactly 1 meter.
"${PSQL[@]}" -c "
  update public.sites set is_active = false where organization_id = '$ORG';
  update public.organization_subscriptions set max_sites = 1 where organization_id = '$ORG';
  insert into public.sites (id, organization_id, name_en, name_ar) values ('$SITE', '$ORG', 'race-host', 'race-host');" >/dev/null
race meters "insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit) values ('$SITE', 'RACE-@I@', 'm', 'm', 'water', 'm3', 'm3')"
METERS="$("${PSQL[@]}" -c "select count(*) from public.meters where site_id = '$SITE' and is_active")"

echo "workers=$WORKERS max_sites=1 active_sites=$SITES max_meters=1 active_meters=$METERS"
status=0
if [ "$SITES" -le 1 ]; then echo "ok 1 - concurrent site inserts cannot exceed max_sites"; else echo "not ok 1 - concurrent site inserts exceeded max_sites ($SITES > 1)"; status=1; fi
if [ "$METERS" -le 1 ]; then echo "ok 2 - concurrent meter inserts cannot exceed max_meters"; else echo "not ok 2 - concurrent meter inserts exceeded max_meters ($METERS > 1)"; status=1; fi
exit $status
