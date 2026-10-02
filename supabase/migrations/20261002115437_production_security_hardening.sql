-- Production security hardening before billing/subscriptions.
-- Principle: authenticated access + least privilege; preserve signed-in RPC access
-- unless the function is an internal/trigger helper.

revoke all privileges on all tables in schema public from anon;
revoke all privileges on all sequences in schema public from anon;

alter policy "profiles_select_own" on public.profiles to authenticated;
alter policy "report_logos_select" on storage.objects to authenticated;
alter policy "report_logos_insert" on storage.objects to authenticated;
alter policy "report_logos_update" on storage.objects to authenticated;
alter policy "report_logos_delete" on storage.objects to authenticated;

do $$
declare
  r record;
  v_authenticated_had_execute boolean;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
  loop
    v_authenticated_had_execute :=
      has_function_privilege('authenticated', r.oid, 'EXECUTE');
    execute format('revoke execute on function %s from public, anon', r.oid::regprocedure);
    if v_authenticated_had_execute then
      execute format('grant execute on function %s to authenticated', r.oid::regprocedure);
    end if;
  end loop;
end
$$;

do $$
declare
  r record;
begin
  for r in
    select distinct p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_trigger t on t.tgfoid = p.oid and not t.tgisinternal
    where n.nspname = 'public' and p.prosecdef
  loop
    execute format('revoke execute on function %s from authenticated', r.oid::regprocedure);
  end loop;
end
$$;

revoke execute on function public.utility_assert_draft_lock(uuid, integer) from authenticated;
revoke execute on function public.utility_bump_draft_lock(uuid) from authenticated;
revoke execute on function public.utility_connect_ports_unlocked(uuid, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb, boolean) from authenticated;
revoke execute on function public.utility_clone_revision_content(uuid, uuid) from authenticated;
revoke execute on function public.utility_default_in_port(uuid) from authenticated;
revoke execute on function public.utility_default_out_port(uuid) from authenticated;
revoke execute on function public.utility_default_ports_for_asset(uuid, text, boolean) from authenticated;
revoke execute on function public.utility_assert_legacy_writes_allowed(uuid, uuid) from authenticated;
revoke execute on function public.utility_legacy_connection_already_in_revision(uuid, uuid, uuid, uuid, text) from authenticated;
revoke execute on function public.utility_legacy_node_already_in_revision(uuid, uuid) from authenticated;

comment on schema public is
  'Application schema. Anonymous SQL access is denied; access is authenticated and RLS/RPC controlled.';
