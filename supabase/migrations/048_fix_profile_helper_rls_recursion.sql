-- =============================================================================
-- Migration: 048_fix_profile_helper_rls_recursion.sql
--
-- Symptom: after login, SELECT on public.profiles (and any RPC that reads
-- profiles under RLS) hangs until statement timeout. All three apps spin.
--
-- Cause: profiles SELECT policy calls is_super_admin() / is_approved_active_user()
-- / current_user_role(), which themselves SELECT from profiles. With FORCE RLS
-- (or equivalent), those SECURITY DEFINER helpers still re-enter the same
-- policy → infinite recursion / lock wait.
--
-- Fix: run helper profile lookups with row_security = off, and expose a
-- get_own_profile() RPC for the client login path.
-- =============================================================================

create or replace function public.is_approved_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and approval_status = 'approved'
      and is_active = true
  );
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'super_admin'
      and approval_status = 'approved'
      and is_active = true
  );
$$;

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select role
  from public.profiles
  where id = auth.uid()
    and approval_status = 'approved'
    and is_active = true;
$$;

-- Fast, non-recursive own-profile read for AuthGate / login.
drop function if exists public.get_own_profile();
create or replace function public.get_own_profile()
returns public.profiles
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select p.*
  from public.profiles p
  where p.id = auth.uid();
$$;

revoke all on function public.get_own_profile() from public;
grant execute on function public.get_own_profile() to authenticated;
grant execute on function public.is_super_admin() to authenticated;
grant execute on function public.is_approved_active_user() to authenticated;
grant execute on function public.current_user_role() to authenticated;

-- Prefer own-row short-circuit; keep admin visibility for user management.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
  on public.profiles
  for select
  using (
    id = auth.uid()
    or public.is_super_admin()
    or (
      public.is_approved_active_user()
      and public.current_user_role() = 'site_admin'::public.user_role
      and (
        approval_status = 'pending'::public.approval_status
        or exists (
          select 1
          from public.user_site_access usa_target
          join public.user_site_access usa_admin
            on usa_admin.site_id = usa_target.site_id
          where usa_target.user_id = profiles.id
            and usa_admin.user_id = auth.uid()
            and usa_admin.role = 'site_admin'::public.user_role
        )
      )
    )
  );
