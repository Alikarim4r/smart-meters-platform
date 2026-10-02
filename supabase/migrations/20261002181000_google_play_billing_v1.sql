-- Google Play Billing v1: server-owned product mapping, verified purchase
-- evidence, append-only billing audit, and the service-role-only boundary that
-- turns verified Google Play evidence into organization entitlements.
-- See docs/regression/GOOGLE_PLAY_BILLING_V1.md (BILL-GP-*).
--
-- Invariants:
--  * Supabase stays the entitlement authority. Google Play is evidence only.
--  * Plan comes from the server mapping; limits/features from
--    subscription_plan_catalog. Nothing client-supplied decides entitlement.
--  * No product rows are seeded: an empty or inactive mapping fails closed.
--  * Only service_role may apply evidence; authenticated clients get no table
--    access and only two scoped RPCs (authorize, catalog).
--  * Raw purchase tokens are stored only in a service-only table; everything
--    else (org row, audit) references sha256(token).

-- ---------------------------------------------------------------------------
-- Product mapping (operator-configured, empty by default)
-- ---------------------------------------------------------------------------
create table public.billing_google_play_products (
  id uuid primary key default gen_random_uuid(),
  package_name text not null
    check (package_name ~ '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$'),
  -- Play product IDs: lowercase letters, digits, '_' and '.', starting with a letter or digit.
  product_id text not null check (product_id ~ '^[a-z0-9][a-z0-9_.]{0,139}$'),
  -- Play base plan IDs: lowercase letters, digits and '-', starting with a letter or digit.
  base_plan_id text not null check (base_plan_id ~ '^[a-z0-9][a-z0-9-]{0,62}$'),
  plan public.subscription_plan not null check (plan <> 'trial'),
  billing_period text not null check (billing_period in ('monthly', 'annual')),
  active boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (package_name, product_id, base_plan_id)
);
create trigger billing_google_play_products_set_updated_at before update on public.billing_google_play_products
  for each row execute function public.set_updated_at();
comment on table public.billing_google_play_products is
  'Server-owned Google Play product/base-plan to subscription_plan mapping. Configured by operators only; empty means billing is disabled.';

-- ---------------------------------------------------------------------------
-- Verified purchase evidence (service-only; holds raw tokens for resync/RTDN)
-- ---------------------------------------------------------------------------
create table public.billing_google_play_purchases (
  purchase_token text primary key check (char_length(purchase_token) between 1 and 4096),
  token_sha256 text not null unique check (token_sha256 ~ '^[0-9a-f]{64}$'),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  product_mapping_id uuid references public.billing_google_play_products(id) on delete set null,
  package_name text not null,
  product_id text not null,
  base_plan_id text not null,
  offer_id text,
  subscription_state text not null,
  acknowledgement_state text,
  expiry_time timestamptz,
  linked_purchase_token_sha256 text,
  superseded_by_token_sha256 text,
  latest_order_id text,
  obfuscated_account_id text,
  is_test_purchase boolean not null default false,
  mapped_status public.subscription_status not null,
  cancel_at_period_end boolean not null default false,
  ack_claimed_at timestamptz,
  acknowledged_at timestamptz,
  first_verified_by uuid references public.profiles(id) on delete set null,
  last_source text not null,
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index billing_google_play_purchases_org_idx on public.billing_google_play_purchases(organization_id);
create trigger billing_google_play_purchases_set_updated_at before update on public.billing_google_play_purchases
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Append-only billing audit. No FK to organizations so history survives org
-- deletion; never stores raw tokens.
-- ---------------------------------------------------------------------------
create table public.billing_events (
  id bigint generated always as identity primary key,
  organization_id uuid,
  provider public.billing_provider not null,
  event_type text not null,
  outcome text not null,
  reason text,
  source text,
  token_sha256 text,
  actor_id uuid,
  provider_state text,
  mapped_status public.subscription_status,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index billing_events_org_created_idx on public.billing_events(organization_id, created_at desc);

create or replace function public.billing_events_append_only() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'BILLING_EVENTS_APPEND_ONLY' using errcode = '42501';
end; $$;
revoke execute on function public.billing_events_append_only() from public, anon, authenticated;
create trigger billing_events_append_only before update or delete on public.billing_events
  for each row execute function public.billing_events_append_only();

-- ---------------------------------------------------------------------------
-- Least privilege. RLS on with no policies: API roles reach these tables only
-- through the functions below. service_role may manage the mapping (operator
-- setup) and read evidence/audit; it writes evidence only via the functions.
-- ---------------------------------------------------------------------------
alter table public.billing_google_play_products enable row level security;
alter table public.billing_google_play_purchases enable row level security;
alter table public.billing_events enable row level security;
revoke all on public.billing_google_play_products, public.billing_google_play_purchases, public.billing_events
  from public, anon, authenticated, service_role;
grant select, insert, update on public.billing_google_play_products to service_role;
grant select on public.billing_google_play_purchases, public.billing_events to service_role;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.billing_token_sha256(p_token text)
returns text language sql immutable strict set search_path = '' as $$
  select encode(sha256(convert_to(p_token, 'UTF8')), 'hex');
$$;
revoke execute on function public.billing_token_sha256(text) from public, anon, authenticated;
grant execute on function public.billing_token_sha256(text) to service_role;

-- Opaque per-org account binding passed to Play as obfuscatedAccountId
-- (applicationUserName) and verified server-side. 48 hex chars (< 64 limit).
create or replace function public.billing_google_play_account_binding(p_organization_id uuid)
returns text language sql immutable strict set search_path = '' as $$
  select left(encode(sha256(convert_to('smart-meters:google-play:org:' || p_organization_id::text, 'UTF8')), 'hex'), 48);
$$;
revoke execute on function public.billing_google_play_account_binding(uuid) from public, anon, authenticated;
grant execute on function public.billing_google_play_account_binding(uuid) to service_role;

-- BILL-GP-STATE: Google subscriptionState -> subscription_status. Fail closed:
-- anything unknown, missing or already past expiry grants nothing.
--   ACTIVE                          -> active (expired if expiry missing/past)
--   IN_GRACE_PERIOD                 -> grace_period until expiry (past_due if missing/past)
--   CANCELED                        -> active + cancel_at_period_end until expiry, then expired
--   EXPIRED                         -> expired
--   ON_HOLD / PAUSED / PENDING      -> past_due (no access)
--   PENDING_PURCHASE_CANCELED / *   -> expired (no access)
create or replace function public.billing_google_play_map_state(
  p_subscription_state text, p_expiry_time timestamptz, p_now timestamptz)
returns table(status public.subscription_status, cancel_at_period_end boolean, grace_period_end timestamptz, entitling boolean)
language sql immutable set search_path = '' as $$
  select m.status, m.cancel, m.grace, m.status in ('active', 'grace_period')
  from (select
    case
      when p_subscription_state = 'SUBSCRIPTION_STATE_ACTIVE' and p_expiry_time > p_now
        then 'active'::public.subscription_status
      when p_subscription_state = 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' and p_expiry_time > p_now
        then 'grace_period'::public.subscription_status
      when p_subscription_state = 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'
        then 'past_due'::public.subscription_status
      when p_subscription_state = 'SUBSCRIPTION_STATE_CANCELED' and p_expiry_time > p_now
        then 'active'::public.subscription_status
      when p_subscription_state in ('SUBSCRIPTION_STATE_ON_HOLD', 'SUBSCRIPTION_STATE_PAUSED', 'SUBSCRIPTION_STATE_PENDING')
        then 'past_due'::public.subscription_status
      else 'expired'::public.subscription_status
    end as status,
    coalesce(p_subscription_state = 'SUBSCRIPTION_STATE_CANCELED' and p_expiry_time > p_now, false) as cancel,
    case when p_subscription_state = 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' and p_expiry_time > p_now
      then p_expiry_time end as grace
  ) m;
$$;
revoke execute on function public.billing_google_play_map_state(text, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.billing_google_play_map_state(text, timestamptz, timestamptz) to service_role;

-- ---------------------------------------------------------------------------
-- Client-facing scoped RPCs
-- ---------------------------------------------------------------------------
-- Used by the Edge Function with the caller's JWT: proves the caller may manage
-- billing for the org and returns the caller id. Same authority as other org
-- management (platform owner or org-scope manager); no new scope semantics.
create or replace function public.billing_google_play_authorize(p_organization_id uuid)
returns uuid language plpgsql stable security invoker set search_path = '' as $$
begin
  if auth.uid() is null or p_organization_id is null
     or not public.user_can_manage_organization(p_organization_id) then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;
  return auth.uid();
end; $$;
revoke execute on function public.billing_google_play_authorize(uuid) from public, anon;
grant execute on function public.billing_google_play_authorize(uuid) to authenticated;

-- Active configured products for the org's billing screen, with server-derived
-- limits and the account binding to pass as applicationUserName. Raises 42501
-- for callers who cannot manage the org (no catalog/binding oracle).
create or replace function public.billing_google_play_catalog(p_organization_id uuid)
returns table(package_name text, product_id text, base_plan_id text, plan public.subscription_plan,
  billing_period text, display_order integer, max_users integer, max_sites integer, max_meters integer,
  features jsonb, account_binding text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or p_organization_id is null
     or not public.user_can_manage_organization(p_organization_id) then
    raise exception 'BILLING_FORBIDDEN' using errcode = '42501';
  end if;
  return query
    select p.package_name, p.product_id, p.base_plan_id, p.plan, p.billing_period, p.display_order,
           c.max_users, c.max_sites, c.max_meters, c.features,
           public.billing_google_play_account_binding(p_organization_id)
      from public.billing_google_play_products p
      join public.subscription_plan_catalog c on c.plan = p.plan
     where p.active
     order by p.display_order, c.display_order, p.billing_period;
end; $$;
revoke execute on function public.billing_google_play_catalog(uuid) from public, anon;
grant execute on function public.billing_google_play_catalog(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- BILL-GP-APPLY: the only path from Google Play evidence to entitlement.
-- Called by the Edge Function (service_role) after subscriptionsv2.get, and
-- later by an RTDN/resync worker. Returns a decision instead of raising for
-- business rejections so the audit row commits.
-- ---------------------------------------------------------------------------
create or replace function public.billing_apply_google_play_verification(
  p_organization_id uuid,
  p_purchase_token text,
  p_package_name text,
  p_product_id text,
  p_base_plan_id text,
  p_offer_id text,
  p_subscription_state text,
  p_acknowledgement_state text,
  p_expiry_time timestamptz,
  p_linked_purchase_token text,
  p_latest_order_id text,
  p_obfuscated_account_id text,
  p_is_test_purchase boolean,
  p_actor_id uuid,
  p_source text)
returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  v_now timestamptz := now();
  v_hash text;
  v_linked_hash text;
  v_product public.billing_google_play_products;
  v_existing public.billing_google_play_purchases;
  v_linked public.billing_google_play_purchases;
  v_sub public.organization_subscriptions;
  v_catalog public.subscription_plan_catalog;
  v_map record;
  v_outcome text := 'recorded';
  v_reason text;
  v_is_current boolean := false;
  v_replaces_current boolean := false;
  v_apply boolean := false;
  v_superseded boolean := false;
  v_acknowledged boolean := false;
  v_has_access boolean;
  v_ack_required boolean := false;
begin
  if p_organization_id is null or p_purchase_token is null
     or char_length(p_purchase_token) not between 1 and 4096
     or p_source is null or p_source not in ('client_verify', 'server_resync', 'rtdn')
     or p_package_name is null or p_product_id is null or p_base_plan_id is null
     or p_subscription_state is null then
    raise exception 'BILLING_INVALID_INPUT' using errcode = '22023';
  end if;
  if not exists (select 1 from public.organizations o where o.id = p_organization_id) then
    raise exception 'BILLING_INVALID_INPUT' using errcode = '22023';
  end if;

  v_hash := public.billing_token_sha256(p_purchase_token);
  v_linked_hash := public.billing_token_sha256(p_linked_purchase_token);

  -- Serialize per org (same lock order as quota triggers), then per token.
  select * into v_sub from public.organization_subscriptions s
   where s.organization_id = p_organization_id for update;
  select * into v_existing from public.billing_google_play_purchases bp
   where bp.purchase_token = p_purchase_token for update;

  -- 'active' gates new sales only: evidence for a token already bound to a
  -- mapping keeps resolving after the product is retired, so expiry/revocation
  -- still propagates to existing subscribers.
  select * into v_product from public.billing_google_play_products bp
   where bp.package_name = p_package_name and bp.product_id = p_product_id
     and bp.base_plan_id = p_base_plan_id
     and (bp.active or bp.id = v_existing.product_mapping_id);

  if v_existing.purchase_token is not null and v_existing.organization_id <> p_organization_id then
    v_outcome := 'rejected'; v_reason := 'TOKEN_BOUND_TO_OTHER_ORGANIZATION';
  elsif v_product.id is null then
    v_outcome := 'rejected'; v_reason := 'PRODUCT_NOT_CONFIGURED';
  elsif p_obfuscated_account_id is null then
    v_outcome := 'rejected'; v_reason := 'ACCOUNT_BINDING_MISSING';
  elsif p_obfuscated_account_id <> public.billing_google_play_account_binding(p_organization_id) then
    v_outcome := 'rejected'; v_reason := 'ACCOUNT_BINDING_MISMATCH';
  end if;

  if v_outcome <> 'rejected' and p_linked_purchase_token is not null then
    select * into v_linked from public.billing_google_play_purchases bp
     where bp.purchase_token = p_linked_purchase_token for update;
    if v_linked.purchase_token is not null and v_linked.organization_id <> p_organization_id then
      v_outcome := 'rejected'; v_reason := 'LINKED_TOKEN_BOUND_TO_OTHER_ORGANIZATION';
    end if;
  end if;

  if v_outcome = 'rejected' then
    insert into public.billing_events (organization_id, provider, event_type, outcome, reason, source,
      token_sha256, actor_id, provider_state, detail)
    values (p_organization_id, 'google_play', 'verification', v_outcome, v_reason, p_source,
      v_hash, p_actor_id, p_subscription_state,
      jsonb_build_object('product_id', p_product_id, 'base_plan_id', p_base_plan_id,
        'package_name', p_package_name, 'is_test_purchase', coalesce(p_is_test_purchase, false)));
    return jsonb_build_object('outcome', v_outcome, 'reason', v_reason, 'token_sha256', v_hash,
      'entitlement_applied', false, 'acknowledgement_required', false);
  end if;

  select * into v_map from public.billing_google_play_map_state(p_subscription_state, p_expiry_time, v_now);

  insert into public.billing_google_play_purchases as bp (purchase_token, token_sha256, organization_id,
    product_mapping_id, package_name, product_id, base_plan_id, offer_id, subscription_state,
    acknowledgement_state, expiry_time, linked_purchase_token_sha256, latest_order_id,
    obfuscated_account_id, is_test_purchase, mapped_status, cancel_at_period_end,
    first_verified_by, last_source, verified_at)
  values (p_purchase_token, v_hash, p_organization_id, v_product.id, p_package_name, p_product_id,
    p_base_plan_id, p_offer_id, p_subscription_state, p_acknowledgement_state, p_expiry_time,
    v_linked_hash, p_latest_order_id, p_obfuscated_account_id, coalesce(p_is_test_purchase, false),
    v_map.status, v_map.cancel_at_period_end, p_actor_id, p_source, v_now)
  on conflict (purchase_token) do update set
    product_mapping_id = excluded.product_mapping_id, product_id = excluded.product_id,
    base_plan_id = excluded.base_plan_id, offer_id = excluded.offer_id,
    subscription_state = excluded.subscription_state,
    acknowledgement_state = case when bp.acknowledged_at is not null
      then 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' else excluded.acknowledgement_state end,
    expiry_time = excluded.expiry_time, linked_purchase_token_sha256 = excluded.linked_purchase_token_sha256,
    latest_order_id = excluded.latest_order_id, obfuscated_account_id = excluded.obfuscated_account_id,
    is_test_purchase = excluded.is_test_purchase, mapped_status = excluded.mapped_status,
    cancel_at_period_end = excluded.cancel_at_period_end, last_source = excluded.last_source,
    verified_at = excluded.verified_at
  returning bp.superseded_by_token_sha256 is not null, bp.acknowledged_at is not null
    into v_superseded, v_acknowledged;

  -- A replacement (upgrade/downgrade/re-signup) that actually took effect
  -- supersedes the linked token, so stale evidence for it can never win later.
  if v_linked.purchase_token is not null
     and p_subscription_state not in ('SUBSCRIPTION_STATE_PENDING', 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED') then
    update public.billing_google_play_purchases set superseded_by_token_sha256 = v_hash
     where purchase_token = v_linked.purchase_token and superseded_by_token_sha256 is null;
  end if;

  v_is_current := v_sub.provider = 'google_play' and v_sub.provider_subscription_ref = v_hash;
  v_replaces_current := v_sub.provider = 'google_play' and v_linked_hash is not null
    and v_sub.provider_subscription_ref = v_linked_hash
    and p_subscription_state not in ('SUBSCRIPTION_STATE_PENDING', 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED');

  if v_superseded then
    v_reason := 'TOKEN_SUPERSEDED';
  elsif v_is_current or v_replaces_current then
    v_apply := true;
  elsif not v_map.entitling then
    v_reason := 'NOT_ENTITLING';
  elsif v_sub.organization_id is not null and v_sub.provider = 'external_contract'
        and public.subscription_row_has_access(v_sub.status, v_sub.current_period_end, v_sub.grace_period_end) then
    v_outcome := 'conflict'; v_reason := 'ACTIVE_EXTERNAL_CONTRACT';
  elsif v_sub.organization_id is not null and v_sub.provider = 'google_play'
        and public.subscription_row_has_access(v_sub.status, v_sub.current_period_end, v_sub.grace_period_end) then
    v_outcome := 'conflict'; v_reason := 'ACTIVE_GOOGLE_PLAY_SUBSCRIPTION';
  else
    v_apply := true;
  end if;

  if v_apply then
    select * into v_catalog from public.subscription_plan_catalog c where c.plan = v_product.plan;
    insert into public.organization_subscriptions as s (organization_id, plan, status, provider,
      provider_customer_ref, provider_subscription_ref, current_period_start, current_period_end,
      grace_period_end, cancel_at_period_end, max_users, max_sites, max_meters, features)
    values (p_organization_id, v_product.plan, v_map.status, 'google_play', p_obfuscated_account_id,
      v_hash, v_now, p_expiry_time, v_map.grace_period_end, v_map.cancel_at_period_end,
      v_catalog.max_users, v_catalog.max_sites, v_catalog.max_meters, v_catalog.features)
    on conflict (organization_id) do update set
      plan = excluded.plan, status = excluded.status, provider = excluded.provider,
      provider_customer_ref = excluded.provider_customer_ref,
      provider_subscription_ref = excluded.provider_subscription_ref,
      current_period_start = case when v_is_current then s.current_period_start else excluded.current_period_start end,
      current_period_end = excluded.current_period_end, grace_period_end = excluded.grace_period_end,
      cancel_at_period_end = excluded.cancel_at_period_end, max_users = excluded.max_users,
      max_sites = excluded.max_sites, max_meters = excluded.max_meters, features = excluded.features;
    v_outcome := 'applied';
    v_ack_required := v_map.entitling and not v_acknowledged
      and coalesce(p_acknowledgement_state, '') = 'ACKNOWLEDGEMENT_STATE_PENDING';
  end if;

  select public.subscription_row_has_access(s.status, s.current_period_end, s.grace_period_end)
    into v_has_access from public.organization_subscriptions s where s.organization_id = p_organization_id;

  insert into public.billing_events (organization_id, provider, event_type, outcome, reason, source,
    token_sha256, actor_id, provider_state, mapped_status, detail)
  values (p_organization_id, 'google_play', 'verification', v_outcome, v_reason, p_source, v_hash,
    p_actor_id, p_subscription_state, v_map.status,
    jsonb_build_object('plan', v_product.plan, 'billing_period', v_product.billing_period,
      'product_id', p_product_id, 'base_plan_id', p_base_plan_id, 'offer_id', p_offer_id,
      'expiry_time', p_expiry_time, 'cancel_at_period_end', v_map.cancel_at_period_end,
      'linked_token_sha256', v_linked_hash, 'replaces_current', v_replaces_current,
      'is_test_purchase', coalesce(p_is_test_purchase, false)));

  return jsonb_build_object('outcome', v_outcome, 'reason', v_reason, 'token_sha256', v_hash,
    'mapped_status', v_map.status, 'plan', v_product.plan, 'entitlement_applied', v_apply,
    'has_access', coalesce(v_has_access, false), 'acknowledgement_required', v_ack_required);
end; $$;
revoke execute on function public.billing_apply_google_play_verification(uuid, text, text, text, text, text, text,
  text, timestamptz, text, text, text, boolean, uuid, text) from public, anon, authenticated;
grant execute on function public.billing_apply_google_play_verification(uuid, text, text, text, text, text, text,
  text, timestamptz, text, text, text, boolean, uuid, text) to service_role;

-- BILL-GP-ACK: single-flight server acknowledgement. 'claim' succeeds for one
-- caller only (stale claims expire after 5 minutes); 'succeeded' records the
-- acknowledgement; 'failed' releases the claim. Prevents double-ack.
create or replace function public.billing_google_play_ack_transition(p_purchase_token text, p_event text)
returns boolean
language plpgsql volatile security definer set search_path = '' as $$
declare v_row public.billing_google_play_purchases; v_ok boolean := false;
begin
  if p_event is null or p_event not in ('claim', 'succeeded', 'failed') then
    raise exception 'BILLING_INVALID_INPUT' using errcode = '22023';
  end if;
  select * into v_row from public.billing_google_play_purchases bp
   where bp.purchase_token = p_purchase_token for update;
  if v_row.purchase_token is null then return false; end if;

  if p_event = 'claim' then
    -- Only the org's current, entitling Play purchase may be acknowledged;
    -- rejected/conflicting purchases stay unacknowledged so Play auto-refunds them.
    if v_row.acknowledged_at is null
       and (v_row.ack_claimed_at is null or v_row.ack_claimed_at < now() - interval '5 minutes')
       and v_row.mapped_status in ('active', 'grace_period')
       and exists (select 1 from public.organization_subscriptions s
                    where s.organization_id = v_row.organization_id and s.provider = 'google_play'
                      and s.provider_subscription_ref = v_row.token_sha256) then
      update public.billing_google_play_purchases set ack_claimed_at = now()
       where purchase_token = p_purchase_token;
      v_ok := true;
    end if;
  elsif p_event = 'succeeded' then
    update public.billing_google_play_purchases
       set acknowledged_at = coalesce(acknowledged_at, now()), ack_claimed_at = null,
           acknowledgement_state = 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
     where purchase_token = p_purchase_token;
    v_ok := true;
  else
    update public.billing_google_play_purchases set ack_claimed_at = null
     where purchase_token = p_purchase_token and acknowledged_at is null;
    v_ok := true;
  end if;

  insert into public.billing_events (organization_id, provider, event_type, outcome, token_sha256, source)
  values (v_row.organization_id, 'google_play', 'acknowledgement_' || p_event,
    case when v_ok then 'ok' else 'skipped' end, v_row.token_sha256, 'server');
  return v_ok;
end; $$;
revoke execute on function public.billing_google_play_ack_transition(text, text) from public, anon, authenticated;
grant execute on function public.billing_google_play_ack_transition(text, text) to service_role;
