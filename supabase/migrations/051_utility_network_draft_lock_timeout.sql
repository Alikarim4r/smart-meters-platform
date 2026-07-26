-- =============================================================================
-- Migration: 051_utility_network_draft_lock_timeout.sql
--
-- Symptom: concurrent network editor RPCs (FOR UPDATE on draft revision) piled
-- up in PostgREST, exhausting the pool so login/get_own_profile hung for all apps.
--
-- Fix: fail fast on draft row locks instead of waiting indefinitely.
-- =============================================================================

create or replace function public.utility_check_draft_lock(
  p_revision_id uuid,
  p_expected_lock_version integer
)
returns public.site_utility_network_revisions
language plpgsql
security definer
set search_path = public
set lock_timeout = '3s'
set statement_timeout = '10s'
as $$
declare
  v_rev public.site_utility_network_revisions;
begin
  perform public.utility_require_auth();

  select * into v_rev
  from public.site_utility_network_revisions
  where id = p_revision_id
  for update;

  if v_rev.id is null then
    raise exception 'Revision not found';
  end if;
  if v_rev.status <> 'draft' then
    raise exception 'Only draft revisions can be mutated';
  end if;
  if not public.can_manage_utility_network(v_rev.network_id) then
    raise exception 'Not allowed to manage this utility network' using errcode = '42501';
  end if;
  if v_rev.lock_version <> p_expected_lock_version then
    raise exception
      'Network draft version conflict: expected %, actual %',
      p_expected_lock_version, v_rev.lock_version
      using errcode = '40001';
  end if;

  return v_rev;
end;
$$;

create or replace function public.utility_assert_draft_lock(
  p_revision_id uuid,
  p_expected_lock_version integer
)
returns public.site_utility_network_revisions
language plpgsql
security definer
set search_path = public
set lock_timeout = '3s'
set statement_timeout = '10s'
as $$
declare
  v_rev public.site_utility_network_revisions;
begin
  v_rev := public.utility_check_draft_lock(p_revision_id, p_expected_lock_version);
  return public.utility_bump_draft_lock(p_revision_id);
end;
$$;
