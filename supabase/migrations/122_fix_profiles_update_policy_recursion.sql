-- =============================================================================
-- Migration: 122_fix_profiles_update_policy_recursion.sql
--
-- Symptom: any UPDATE on public.profiles by an `authenticated` caller fails
-- with SQLSTATE 42P17 "infinite recursion detected in policy for relation
-- profiles" (surfaced by supabase/tests/platform_owner_authority_test.sql
-- after 120; previously noted in 021 and worked around with an RPC).
--
-- Cause: the "profiles_update_own" WITH CHECK (005) contains sub-selects on
-- public.profiles itself. The rewriter expands profiles' SELECT policy inside
-- the UPDATE policy on the same relation → recursion is detected at rewrite
-- time, before any trigger runs. 048 fixed the helper functions but not this
-- policy.
--
-- Fix: same semantics, recursion-free. The "privileged columns unchanged"
-- comparison moves into a SECURITY DEFINER helper with row_security = off
-- (the 048 pattern). Being STABLE, it reads the statement snapshot, i.e. the
-- pre-update row — identical to the old sub-selects.
--
-- Rules preserved:
--   * USING: own row, or super admin.
--   * WITH CHECK: super admin, or own row with role / approval_status /
--     is_active unchanged (no self-escalation, self-approval, self-activation).
--   * email lock and is_platform_owner enforcement from 120 still apply
--     (BEFORE UPDATE triggers).
--
-- Non-destructive: one function + policy replacement; no data changes.
-- =============================================================================

create or replace function public.profile_self_update_keeps_privileges(
  p_id uuid,
  p_role public.user_role,
  p_approval_status public.approval_status,
  p_is_active boolean
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select p_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = p_role
        and p.approval_status = p_approval_status
        and p.is_active = p_is_active
    );
$$;

comment on function public.profile_self_update_keeps_privileges(uuid, public.user_role, public.approval_status, boolean) is
  'RLS helper for profiles_update_own: true when the new row is the caller''s own and role/approval_status/is_active equal the stored values. row_security off to avoid 42P17 recursion.';

revoke all on function public.profile_self_update_keeps_privileges(uuid, public.user_role, public.approval_status, boolean)
  from public, anon;
grant execute on function public.profile_self_update_keeps_privileges(uuid, public.user_role, public.approval_status, boolean)
  to authenticated;

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (id = auth.uid() or public.is_super_admin())
  with check (
    public.is_super_admin()
    or public.profile_self_update_keeps_privileges(id, role, approval_status, is_active)
  );
