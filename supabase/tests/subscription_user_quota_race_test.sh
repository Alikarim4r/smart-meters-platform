#!/usr/bin/env bash
# Concurrency regression for the max_users seat quota (migration 20261002180000).
# N parallel transactions each grant a different new user a seat while the org
# has room for exactly one. With atomic enforcement at most one may commit.
# Commits real rows, so it cleans up after itself.
#
# DISPOSABLE/LOCAL DATABASES ONLY. Requires an explicit connection URL:
#   SUBSCRIPTION_GATE_DB_URL=postgresql://postgres:postgres@127.0.0.1:55422/billing_v1_test \
#     supabase/tests/subscription_user_quota_race_test.sh
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
TAG="seat-race-${ORG:0:8}"

cleanup() {
  "${PSQL[@]}" -c "
    delete from public.user_site_access where site_id = '$SITE';
    delete from public.sites where id = '$SITE';
    delete from public.organization_subscriptions where organization_id = '$ORG';
    delete from public.organizations where id = '$ORG';
    delete from auth.users where email like '$TAG-%@example.test';" >/dev/null
}
trap cleanup EXIT

"${PSQL[@]}" -c "
  insert into public.organizations (id, name_en, name_ar) values ('$ORG', 'seat-race-org', 'seat-race-org');
  update public.organization_subscriptions set plan = 'starter', status = 'active',
    current_period_end = now() + interval '1 day', grace_period_end = null,
    max_users = 1, max_sites = 5, max_meters = 5 where organization_id = '$ORG';
  insert into public.sites (id, organization_id, name_en, name_ar) values ('$SITE', '$ORG', 'seat-race', 'seat-race');
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    select gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      '$TAG-' || i || '@example.test', now(), '{}', '{}', now(), now() from generate_series(1, $WORKERS) i;
  insert into public.profiles (id, full_name, email, role, is_active, approval_status)
    select id, 'seat race', email, 'viewer', true, 'approved' from auth.users where email like '$TAG-%@example.test'
  on conflict (id) do update set approval_status = 'approved';" >/dev/null

pids=()
for i in $(seq 1 "$WORKERS"); do
  "${PSQL[@]}" -c "begin;
    insert into public.user_site_access (user_id, site_id, role, can_read)
      select id, '$SITE', 'viewer', true from auth.users where email = '$TAG-$i@example.test';
    select pg_sleep(0.5); commit;" >/dev/null 2>&1 &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p" || true; done

SEATS="$("${PSQL[@]}" -c "select count(distinct user_id) from public.user_site_access where site_id = '$SITE'")"
echo "workers=$WORKERS max_users=1 seats=$SEATS"
if [ "$SEATS" -le 1 ]; then echo "ok 1 - concurrent seat grants cannot exceed max_users"; exit 0; fi
echo "not ok 1 - concurrent seat grants exceeded max_users ($SEATS > 1)"; exit 1
