-- Subscription Security & Enforcement Gate hardening (follow-up to 20261002170000).
-- See docs/regression/SUBSCRIPTION_SECURITY_ENFORCEMENT_GATE.md (SUB-GATE-01..10).

-- SUB-GATE-01/02: least-privilege table grants. Supabase default privileges left
-- TRUNCATE/REFERENCES/TRIGGER with authenticated; TRUNCATE bypasses RLS.
-- Billing provider references are server-only.
revoke all on public.subscription_plan_catalog, public.organization_subscriptions from public, anon, authenticated;
grant select on public.subscription_plan_catalog to authenticated;
grant select (organization_id, plan, status, provider, current_period_start, current_period_end,
  grace_period_end, cancel_at_period_end, max_users, max_sites, max_meters, features, created_at, updated_at)
  on public.organization_subscriptions to authenticated;

-- SUB-GATE-07: single definition of "entitled". Trials and paid periods end at
-- current_period_end (null = open-ended contract); grace ends at grace_period_end.
create or replace function public.subscription_row_has_access(
  p_status public.subscription_status, p_current_period_end timestamptz, p_grace_period_end timestamptz)
returns boolean language sql stable set search_path = '' as $$
  select case p_status
    when 'trialing' then p_current_period_end is null or p_current_period_end > now()
    when 'active' then p_current_period_end is null or p_current_period_end > now()
    when 'grace_period' then p_grace_period_end is null or p_grace_period_end > now()
    else false
  end;
$$;
revoke execute on function public.subscription_row_has_access(public.subscription_status, timestamptz, timestamptz) from public, anon;
grant execute on function public.subscription_row_has_access(public.subscription_status, timestamptz, timestamptz) to authenticated;

create or replace function public.subscription_access_state(p_organization_id uuid)
returns table(plan public.subscription_plan,status public.subscription_status,has_access boolean,max_users integer,max_sites integer,max_meters integer,current_period_end timestamptz,grace_period_end timestamptz,features jsonb)
language sql stable security invoker set search_path='' as $$
 select s.plan,s.status,
   public.subscription_row_has_access(s.status, s.current_period_end, s.grace_period_end),
   s.max_users,s.max_sites,s.max_meters,s.current_period_end,s.grace_period_end,s.features
 from public.organization_subscriptions s
 where s.organization_id=p_organization_id and (
   public.is_platform_owner() or public.user_can_manage_organization(p_organization_id)
   or exists(select 1 from public.sites si where si.organization_id=p_organization_id and public.has_site_access(si.id)))
 limit 1;
$$;

-- SUB-GATE-05: feature probe is caller-scoped (RLS) instead of SECURITY DEFINER,
-- and only a JSON boolean true grants a feature (no cast errors).
create or replace function public.subscription_has_feature(p_organization_id uuid, p_feature text)
returns boolean language sql stable security invoker set search_path = '' as $$
 select coalesce(exists(
   select 1 from public.organization_subscriptions s
   where s.organization_id = p_organization_id
     and public.subscription_row_has_access(s.status, s.current_period_end, s.grace_period_end)
     and s.features -> p_feature = 'true'::jsonb
 ), false);
$$;
revoke execute on function public.subscription_has_feature(uuid, text) from public, anon;
grant execute on function public.subscription_has_feature(uuid, text) to authenticated;

-- SUB-GATE-03: serialize quota checks per organization by locking the
-- subscription row; concurrent creators wait and recount after commit.
create or replace function public.subscription_lock_for_quota(p_organization_id uuid)
returns public.organization_subscriptions
language plpgsql security definer set search_path = '' as $$
declare s public.organization_subscriptions;
begin
  select * into s from public.organization_subscriptions
  where organization_id = p_organization_id for update;
  if not found then raise exception 'SUBSCRIPTION_REQUIRED'; end if;
  if s.status not in ('trialing','active','grace_period') then raise exception 'SUBSCRIPTION_INACTIVE'; end if;
  if not public.subscription_row_has_access(s.status, s.current_period_end, s.grace_period_end) then
    raise exception 'SUBSCRIPTION_EXPIRED';
  end if;
  return s;
end; $$;
revoke execute on function public.subscription_lock_for_quota(uuid) from public, anon, authenticated;

-- SUB-GATE-03/06/08: quota triggers run AFTER the row (so RLS WITH CHECK rejects
-- unauthorized callers first: no cross-tenant quota oracle), lock per org, and
-- a site moved between orgs carries its meters into the target meter quota.
create or replace function public.enforce_subscription_site_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  s public.organization_subscriptions; n bigint;
  v_moved boolean := tg_op = 'UPDATE' and new.organization_id is distinct from old.organization_id;
begin
  if not v_moved and (new.is_active is not true or (tg_op = 'UPDATE' and old.is_active is true)) then
    return null;
  end if;
  s := public.subscription_lock_for_quota(new.organization_id);
  if v_moved then
    select count(*) into n from public.meters m join public.sites si on si.id = m.site_id
     where si.organization_id = new.organization_id and m.is_active = true;
    if n > s.max_meters then raise exception 'SUBSCRIPTION_METER_LIMIT_REACHED:%', s.max_meters; end if;
  end if;
  if new.is_active is true then
    select count(*) into n from public.sites
     where organization_id = new.organization_id and is_active = true and id <> new.id;
    if n >= s.max_sites then raise exception 'SUBSCRIPTION_SITE_LIMIT_REACHED:%', s.max_sites; end if;
  end if;
  return null;
end; $$;

create or replace function public.enforce_subscription_meter_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare s public.organization_subscriptions; v_org uuid; n bigint;
begin
  if new.is_active is not true or (tg_op = 'UPDATE' and old.is_active is true and old.site_id = new.site_id) then
    return null;
  end if;
  select organization_id into v_org from public.sites where id = new.site_id;
  s := public.subscription_lock_for_quota(v_org);
  select count(*) into n from public.meters m join public.sites si on si.id = m.site_id
   where si.organization_id = v_org and m.is_active = true and m.id <> new.id;
  if n >= s.max_meters then raise exception 'SUBSCRIPTION_METER_LIMIT_REACHED:%', s.max_meters; end if;
  return null;
end; $$;

drop trigger if exists enforce_subscription_site_limit on public.sites;
create trigger enforce_subscription_site_limit after insert or update of is_active, organization_id on public.sites
for each row execute function public.enforce_subscription_site_limit();
drop trigger if exists enforce_subscription_meter_limit on public.meters;
create trigger enforce_subscription_meter_limit after insert or update of is_active, site_id on public.meters
for each row execute function public.enforce_subscription_meter_limit();
revoke execute on function public.enforce_subscription_site_limit() from public, anon, authenticated;
revoke execute on function public.enforce_subscription_meter_limit() from public, anon, authenticated;

-- SUB-GATE-04: tenant boundary for sites. Only the platform owner (or a
-- service/DB session without a JWT subject) may move a site between orgs, and a
-- site's zone must belong to the site's organization.
create or replace function public.sites_guard_tenant_scope() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.organization_id is distinct from old.organization_id
     and auth.uid() is not null and not public.is_platform_owner() then
    raise exception 'SITE_ORGANIZATION_CHANGE_FORBIDDEN' using errcode = '42501';
  end if;
  if new.zone_id is not null and not exists (
    select 1 from public.zones z where z.id = new.zone_id and z.organization_id = new.organization_id
  ) then
    raise exception 'SITE_ZONE_ORGANIZATION_MISMATCH' using errcode = '42501';
  end if;
  return new;
end; $$;
revoke execute on function public.sites_guard_tenant_scope() from public, anon, authenticated;
create trigger sites_guard_tenant_scope before insert or update of organization_id, zone_id on public.sites
for each row execute function public.sites_guard_tenant_scope();

-- SUB-GATE-09: new organizations get a server-provisioned trial from the catalog
-- (previously they had no row and every site/meter create failed closed).
create or replace function public.provision_organization_trial_subscription() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.organization_subscriptions
    (organization_id, plan, status, provider, current_period_start, current_period_end,
     max_users, max_sites, max_meters, features)
  select new.id, c.plan, 'trialing', 'manual', now(), now() + make_interval(days => c.trial_days),
     c.max_users, c.max_sites, c.max_meters, c.features
  from public.subscription_plan_catalog c where c.plan = 'trial'
  on conflict (organization_id) do nothing;
  return null;
end; $$;
revoke execute on function public.provision_organization_trial_subscription() from public, anon, authenticated;
create trigger organizations_provision_trial_subscription after insert on public.organizations
for each row execute function public.provision_organization_trial_subscription();
