-- =============================================================================
-- Migration: 021_set_backdate_permission_rpc.sql
-- Direct UPDATE on profiles by admins trips policy recursion
-- ("infinite recursion detected in policy for relation profiles"), so the
-- backdating permission is toggled through a security-definer RPC instead.
-- =============================================================================

create or replace function public.admin_set_backdate_permission(
  p_user_id uuid,
  p_allowed boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can change backdating permission';
  end if;

  update public.profiles
  set
    allow_backdated_readings = p_allowed,
    updated_at = now()
  where id = p_user_id;

  if not found then
    raise exception 'User not found';
  end if;
end;
$$;

revoke all on function public.admin_set_backdate_permission(uuid, boolean) from public;
grant execute on function public.admin_set_backdate_permission(uuid, boolean) to authenticated;
