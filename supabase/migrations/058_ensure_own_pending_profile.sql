-- =============================================================================
-- Migration: 058_ensure_own_pending_profile.sql
--
-- Self-registration can leave auth.users without a profiles row if the
-- on_auth_user_created trigger is missing/misconfigured. Login then fails with
-- "Could not load profile". This RPC creates a pending profile for the caller
-- when missing, matching handle_new_user defaults.
-- =============================================================================

create or replace function public.ensure_own_pending_profile()
returns public.profiles
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.profiles;
  v_email text;
  v_full_name text;
  v_role_text text;
  v_role public.user_role;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_row from public.profiles where id = v_uid;
  if found then
    return v_row;
  end if;

  select
    u.email,
    coalesce(
      nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''),
      split_part(coalesce(u.email, 'user'), '@', 1)
    ),
    lower(trim(coalesce(
      nullif(u.raw_user_meta_data ->> 'requested_role', ''),
      nullif(u.raw_user_meta_data ->> 'role', ''),
      'viewer'
    )))
  into v_email, v_full_name, v_role_text
  from auth.users u
  where u.id = v_uid;

  if v_email is null then
    raise exception 'Auth user not found';
  end if;

  case v_role_text
    when 'technician_request' then
      v_role := 'technician_request';
    when 'viewer' then
      v_role := 'viewer';
    when 'super_admin', 'site_admin', 'technician' then
      v_role := 'technician_request';
    else
      v_role := 'viewer';
  end case;

  insert into public.profiles (
    id,
    full_name,
    email,
    role,
    is_active,
    approval_status
  )
  values (
    v_uid,
    v_full_name,
    v_email,
    v_role,
    false,
    'pending'
  )
  on conflict (id) do update
    set email = excluded.email
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.ensure_own_pending_profile() from public;
grant execute on function public.ensure_own_pending_profile() to authenticated;

-- Harden get_own_profile to return a single JSON-friendly row even when empty.
create or replace function public.get_own_profile()
returns public.profiles
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
declare
  v_row public.profiles;
begin
  select p.* into v_row
  from public.profiles p
  where p.id = auth.uid();
  return v_row; -- may be null
end;
$$;

revoke all on function public.get_own_profile() from public;
grant execute on function public.get_own_profile() to authenticated;
