-- =============================================================================
-- 101: Allow maintenance inserts on automation_rules when no JWT present
-- (postgres/bypass scripts). Authenticated sessions still enforced.
-- =============================================================================

create or replace function public.enforce_automation_rules_admin_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.user_role;
  v_sub text;
begin
  v_sub := nullif(current_setting('request.jwt.claim.sub', true), '');
  -- Maintenance / migration path (no JWT): allow.
  if v_sub is null then
    return new;
  end if;

  v_role := public.current_user_role();
  if v_role is null then
    raise exception 'Authentication required';
  end if;
  if v_role = 'technician'::public.user_role then
    raise exception 'Technicians cannot manage automation rules';
  end if;
  if v_role = 'viewer'::public.user_role then
    raise exception 'Viewers cannot manage automation rules';
  end if;
  if TG_OP = 'UPDATE' and new.enabled = true and coalesce(old.enabled, false) = false then
    if not (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.user_can_manage_organization(new.organization_id)
      or public.current_user_role() = 'site_admin'::public.user_role
    ) then
      raise exception 'Only admins can activate automation rules';
    end if;
    new.activated_by := auth.uid();
    new.activated_at := now();
  end if;
  return new;
end;
$$;
