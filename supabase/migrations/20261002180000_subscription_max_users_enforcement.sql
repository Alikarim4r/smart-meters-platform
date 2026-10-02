-- Server-side max_users enforcement (residual risk #2 of
-- docs/regression/SUBSCRIPTION_SECURITY_ENFORCEMENT_GATE.md), required before billing.
-- See docs/regression/GOOGLE_PLAY_BILLING_V1.md (BILL-SEAT-*).
--
-- A "seat" is a distinct user holding any access grant inside an organization:
--   * an active user_scope_assignments row at org, zone or site scope, or
--   * a legacy user_site_access row on one of the org's sites.
-- Profile state is deliberately ignored: a suspended profile can be reactivated
-- without touching its grants, so its grants keep holding the seat (fail closed).
-- A seat is freed by deactivating/removing the grant rows.

-- Single seat definition. SECURITY INVOKER: callers only see grants that RLS
-- already shows them; the SECURITY DEFINER triggers below see every grant.
create or replace function public.subscription_org_seat_grants(p_organization_id uuid)
returns table(user_id uuid, grant_id uuid)
language sql stable security invoker set search_path = '' as $$
  select usa.user_id, usa.id from public.user_scope_assignments usa
   where usa.status = 'active' and usa.organization_id = p_organization_id
  union all
  select usa.user_id, usa.id from public.user_scope_assignments usa
    join public.zones z on z.id = usa.zone_id
   where usa.status = 'active' and z.organization_id = p_organization_id
  union all
  select usa.user_id, usa.id from public.user_scope_assignments usa
    join public.sites si on si.id = usa.site_id
   where usa.status = 'active' and si.organization_id = p_organization_id
  union all
  select usa.user_id, usa.id from public.user_site_access usa
    join public.sites si on si.id = usa.site_id
   where si.organization_id = p_organization_id;
$$;
revoke execute on function public.subscription_org_seat_grants(uuid) from public, anon;
grant execute on function public.subscription_org_seat_grants(uuid) to authenticated, service_role;

-- Usage reporting now counts zone/site-scoped and legacy grants (previously only
-- org-scoped assignments were counted, under-reporting seats).
create or replace function public.subscription_usage(p_organization_id uuid)
returns table(active_users bigint,active_sites bigint,active_meters bigint,max_users integer,max_sites integer,max_meters integer)
language sql stable security invoker set search_path='' as $$
 select
   (select count(distinct g.user_id) from public.subscription_org_seat_grants(p_organization_id) g),
   (select count(*) from public.sites si where si.organization_id=p_organization_id and si.is_active=true),
   (select count(*) from public.meters m join public.sites si on si.id=m.site_id where si.organization_id=p_organization_id and m.is_active=true),
   s.max_users,s.max_sites,s.max_meters
 from public.organization_subscriptions s
 where s.organization_id=p_organization_id and (
   public.is_platform_owner() or public.user_can_manage_organization(p_organization_id)
   or exists(select 1 from public.sites si where si.organization_id=p_organization_id and public.has_site_access(si.id)))
 limit 1;
$$;

-- BILL-SEAT-01: after any grant write, the org's distinct seats must fit
-- max_users. AFTER ROW so RLS WITH CHECK rejects unauthorized writers first (no
-- cross-tenant quota oracle); AFTER ROW triggers fire once the whole statement
-- is applied, so multi-row writes are counted together; the per-org
-- subscription row lock serializes concurrent grants. Extra grants for an
-- already-seated user add no seat and pass while the org is within quota.
-- Downgrades are non-retroactive (existing grants stay), but an org over quota
-- cannot add grants until it is back within max_users.
create or replace function public.enforce_subscription_user_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  s public.organization_subscriptions;
  v_org uuid;
  n bigint;
begin
  if tg_table_name = 'user_scope_assignments' then
    if new.status <> 'active' then return null; end if;
    if tg_op = 'UPDATE' and old.status = 'active' and old.user_id = new.user_id
       and old.organization_id is not distinct from new.organization_id
       and old.zone_id is not distinct from new.zone_id
       and old.site_id is not distinct from new.site_id then
      return null;
    end if;
    v_org := coalesce(new.organization_id,
      (select z.organization_id from public.zones z where z.id = new.zone_id),
      (select si.organization_id from public.sites si where si.id = new.site_id));
  else
    if tg_op = 'UPDATE' and old.user_id = new.user_id and old.site_id = new.site_id then
      return null;
    end if;
    v_org := (select si.organization_id from public.sites si where si.id = new.site_id);
  end if;
  if v_org is null then raise exception 'SUBSCRIPTION_REQUIRED'; end if;

  s := public.subscription_lock_for_quota(v_org);
  select count(distinct g.user_id) into n from public.subscription_org_seat_grants(v_org) g;
  if n > s.max_users then raise exception 'SUBSCRIPTION_USER_LIMIT_REACHED:%', s.max_users; end if;
  return null;
end; $$;
revoke execute on function public.enforce_subscription_user_limit() from public, anon, authenticated;

create trigger enforce_subscription_user_limit
after insert or update of status, user_id, organization_id, zone_id, site_id on public.user_scope_assignments
for each row execute function public.enforce_subscription_user_limit();
create trigger enforce_subscription_user_limit
after insert or update of user_id, site_id on public.user_site_access
for each row execute function public.enforce_subscription_user_limit();

-- BILL-SEAT-02: moving a site or zone between orgs (platform owner / service
-- only, see sites_guard_tenant_scope) carries its users into the target's seats.
create or replace function public.enforce_subscription_user_limit_on_move() returns trigger
language plpgsql security definer set search_path = '' as $$
declare s public.organization_subscriptions; n bigint;
begin
  if new.organization_id is not distinct from old.organization_id then return null; end if;
  s := public.subscription_lock_for_quota(new.organization_id);
  select count(distinct g.user_id) into n from public.subscription_org_seat_grants(new.organization_id) g;
  if n > s.max_users then raise exception 'SUBSCRIPTION_USER_LIMIT_REACHED:%', s.max_users; end if;
  return null;
end; $$;
revoke execute on function public.enforce_subscription_user_limit_on_move() from public, anon, authenticated;

create trigger enforce_subscription_user_limit_on_move
after update of organization_id on public.sites
for each row execute function public.enforce_subscription_user_limit_on_move();
create trigger enforce_subscription_user_limit_on_move
after update of organization_id on public.zones
for each row execute function public.enforce_subscription_user_limit_on_move();
