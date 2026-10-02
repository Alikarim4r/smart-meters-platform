#!/usr/bin/env bash
# API-path (Kong -> PostgREST) smoke for the Subscription Security Gate.
# Exercises the same exploits as subscription_security_gate_test.sql through
# HTTP with forged/real JWTs. Commits a small fixture and removes it on exit.
#
# DISPOSABLE/LOCAL STACKS ONLY:
#   SUBSCRIPTION_GATE_DB_URL=postgresql://postgres:postgres@127.0.0.1:55422/postgres \
#   SUBSCRIPTION_GATE_API_URL=http://127.0.0.1:55421 \
#   SUBSCRIPTION_GATE_JWT_SECRET=<local stack JWT secret> \
#     supabase/tests/subscription_api_smoke_test.sh
set -euo pipefail

DB_URL="${SUBSCRIPTION_GATE_DB_URL:?}"; API="${SUBSCRIPTION_GATE_API_URL:?}"; SECRET="${SUBSCRIPTION_GATE_JWT_SECRET:?}"
for u in "$DB_URL" "$API"; do
  case "$u" in *127.0.0.1:*|*localhost:*) ;; *) echo "refusing non-local target: $u" >&2; exit 2 ;; esac
  case "$u" in *:54322*|*:54321*) echo "refusing reserved local stack: $u" >&2; exit 2 ;; esac
done

PSQL=(psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1)
id() { uuidgen | tr 'A-Z' 'a-z'; }
ORG_A=$(id); ORG_B=$(id); SITE_A=$(id); SITE_B=$(id); ZONE_B=$(id); SA=$(id); VW=$(id); OB=$(id)

jwt() { # $1 = role, $2 = sub (optional), $3 = extra claims json (optional)
  local extra=${3:-}; [ -n "$extra" ] || extra='{}'
  python3 - "$SECRET" "$1" "${2:-}" "$extra" <<'PY'
import base64, hashlib, hmac, json, sys, time
secret, role, sub, extra = sys.argv[1], sys.argv[2], sys.argv[3], json.loads(sys.argv[4])
b = lambda d: base64.urlsafe_b64encode(json.dumps(d, separators=(',', ':')).encode()).rstrip(b'=')
claims = {"role": role, "iss": "supabase-demo", "exp": int(time.time()) + 600, **extra}
if sub: claims.update(sub=sub, aud="authenticated")
msg = b({"alg": "HS256", "typ": "JWT"}) + b"." + b(claims)
sig = base64.urlsafe_b64encode(hmac.new(secret.encode(), msg, hashlib.sha256).digest()).rstrip(b'=')
print((msg + b"." + sig).decode())
PY
}
ANON=$(jwt anon)

cleanup() {
  "${PSQL[@]}" -c "
    delete from public.user_scope_assignments where user_id in ('$SA','$VW','$OB');
    delete from public.sites where organization_id in ('$ORG_A','$ORG_B');
    delete from public.zones where id = '$ZONE_B';
    delete from public.organizations where id in ('$ORG_A','$ORG_B');
    delete from public.profiles where id in ('$SA','$VW','$OB');
    delete from auth.users where id in ('$SA','$VW','$OB');" >/dev/null
}
trap cleanup EXIT

"${PSQL[@]}" -c "
  insert into public.organizations (id, name_en, name_ar) values ('$ORG_A','api-a','api-a'), ('$ORG_B','api-b','api-b');
  update public.organization_subscriptions set plan='starter', status='active', max_sites=2, max_meters=3,
    current_period_end = now() + interval '30 days', provider_subscription_ref = 'secret-' || organization_id
    where organization_id in ('$ORG_A','$ORG_B');
  insert into public.zones (id, organization_id, code, name_en, name_ar) values ('$ZONE_B','$ORG_B','api_zb','zb','zb');
  insert into public.sites (id, organization_id, name_en, name_ar) values ('$SITE_A','$ORG_A','api-sa','api-sa'), ('$SITE_B','$ORG_B','api-sb','api-sb');
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'api-' || u || '@example.test', now(), '{}', '{}', now(), now()
  from unnest(array['$SA','$VW','$OB']::uuid[]) u;
  insert into public.profiles (id, full_name, email, role, is_active, approval_status)
  select u, 'api', 'api-' || u || '@example.test', 'site_admin', true, 'approved' from unnest(array['$SA','$VW','$OB']::uuid[]) u
  on conflict (id) do update set role = 'site_admin', is_active = true, approval_status = 'approved';
  insert into public.user_scope_assignments (user_id, role_id, site_id) values
    ('$SA', (select id from public.roles where code='site_admin'), '$SITE_A'),
    ('$VW', (select id from public.roles where code='viewer'), '$SITE_A');
  insert into public.user_scope_assignments (user_id, role_id, organization_id) values
    ('$OB', (select id from public.roles where code='org_admin'), '$ORG_B');" >/dev/null

FORGED='{"plan":"enterprise","max_sites":1000000,"subscription_status":"active","user_role":"super_admin","app_metadata":{"role":"super_admin"}}'
T_SA=$(jwt authenticated "$SA" "$FORGED"); T_VW=$(jwt authenticated "$VW" "$FORGED"); T_OB=$(jwt authenticated "$OB")

n=0; fail=0
check() { # $1 desc, $2 expected-regex for "status body", then curl args
  local desc=$1 want=$2; shift 2
  local out; out=$(curl -s -w ' %{http_code}' "$@")
  n=$((n+1))
  if [[ "$out" =~ $want ]]; then echo "ok $n - $desc"; else echo "not ok $n - $desc :: $out"; fail=1; fi
}
H=(-H "apikey: $ANON" -H 'Content-Type: application/json' -H 'Prefer: return=representation')

check "anon cannot read subscriptions" ' 40[13]$' "${H[@]}" -H "Authorization: Bearer $ANON" "$API/rest/v1/organization_subscriptions?select=plan"
check "anon cannot call subscription_access_state" ' 40[13]$' "${H[@]}" -H "Authorization: Bearer $ANON" -X POST "$API/rest/v1/rpc/subscription_access_state" -d "{\"p_organization_id\":\"$ORG_A\"}"
check "viewer (forged claims) cannot PATCH max_sites" ' 40[13]$' "${H[@]}" -H "Authorization: Bearer $T_VW" -X PATCH "$API/rest/v1/organization_subscriptions?organization_id=eq.$ORG_A" -d '{"max_sites":1000}'
check "viewer cannot INSERT subscription" ' 40[13]$' "${H[@]}" -H "Authorization: Bearer $T_VW" -X POST "$API/rest/v1/organization_subscriptions" -d "{\"organization_id\":\"$ORG_B\",\"max_users\":1,\"max_sites\":999,\"max_meters\":999}"
check "viewer cannot read provider refs" ' 40[13]$' "${H[@]}" -H "Authorization: Bearer $T_VW" "$API/rest/v1/organization_subscriptions?select=provider_subscription_ref"
check "viewer gets server max_sites despite forged claim" '"max_sites":2.* 200$' "${H[@]}" -H "Authorization: Bearer $T_VW" -X POST "$API/rest/v1/rpc/subscription_access_state" -d "{\"p_organization_id\":\"$ORG_A\"}"
check "viewer cannot read org B entitlement (IDOR)" '^\[\] 200$' "${H[@]}" -H "Authorization: Bearer $T_VW" -X POST "$API/rest/v1/rpc/subscription_access_state" -d "{\"p_organization_id\":\"$ORG_B\"}"
check "viewer cannot probe org B features (IDOR)" '^false 200$' "${H[@]}" -H "Authorization: Bearer $T_VW" -X POST "$API/rest/v1/rpc/subscription_has_feature" -d "{\"p_organization_id\":\"$ORG_B\",\"p_feature\":\"dashboard\"}"
check "viewer cannot create site" ' 403$' "${H[@]}" -H "Authorization: Bearer $T_VW" -X POST "$API/rest/v1/sites" -d "{\"organization_id\":\"$ORG_A\",\"name_en\":\"x\",\"name_ar\":\"x\"}"
check "site admin (forged) cannot create site" ' 403$' "${H[@]}" -H "Authorization: Bearer $T_SA" -X POST "$API/rest/v1/sites" -d "{\"organization_id\":\"$ORG_A\",\"name_en\":\"x\",\"name_ar\":\"x\"}"
check "site admin cannot move site to org B" 'SITE_ORGANIZATION_CHANGE_FORBIDDEN.* 403$' "${H[@]}" -H "Authorization: Bearer $T_SA" -X PATCH "$API/rest/v1/sites?id=eq.$SITE_A" -d "{\"organization_id\":\"$ORG_B\"}"
check "site admin cannot attach site to org B zone" 'SITE_ZONE_ORGANIZATION_MISMATCH.* 403$' "${H[@]}" -H "Authorization: Bearer $T_SA" -X PATCH "$API/rest/v1/sites?id=eq.$SITE_A" -d "{\"zone_id\":\"$ZONE_B\"}"
check "org admin B cannot plant site in org A via own zone" ' 403$' "${H[@]}" -H "Authorization: Bearer $T_OB" -X POST "$API/rest/v1/sites" -d "{\"organization_id\":\"$ORG_A\",\"zone_id\":\"$ZONE_B\",\"name_en\":\"p\",\"name_ar\":\"p\"}"
# return=minimal: INSERT..RETURNING on sites is denied for scope-model admins by a
# pre-existing sites_select visibility issue (documented residual, not gate scope).
M=(-H "apikey: $ANON" -H 'Content-Type: application/json' -H 'Prefer: return=minimal')
check "org admin B creates site N within quota (legit)" ' 201$' "${M[@]}" -H "Authorization: Bearer $T_OB" -X POST "$API/rest/v1/sites" -d "{\"organization_id\":\"$ORG_B\",\"name_en\":\"b2\",\"name_ar\":\"b2\"}"
check "org admin B site N+1 rejected by quota" 'SUBSCRIPTION_SITE_LIMIT_REACHED:2' "${M[@]}" -H "Authorization: Bearer $T_OB" -X POST "$API/rest/v1/sites" -d "{\"organization_id\":\"$ORG_B\",\"name_en\":\"b3\",\"name_ar\":\"b3\"}"

echo "1..$n"
exit $fail
