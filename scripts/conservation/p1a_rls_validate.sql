-- P1A RLS validation for conservation_feature_flags
-- Roles: viewer, technician, site_admin, super_admin

do $$
declare
  v_viewer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  v_tech uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_site_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_super uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_osman uuid := 'b82f2bb2-b85c-472e-b6e3-69c1ac97c1fb';
  v_ali uuid := 'e61ac413-2634-46d5-b8dd-f0b5f2f28875';
  v_arwa uuid := '841c5009-959a-4cac-8f42-4efc3cbb517e';
  v_org uuid := '11111111-1111-4111-8111-111111111111';
  v_cnt int;
  v_ok boolean;
  v_updated int;
begin
  delete from public.conservation_feature_flags where flag_key like 'p1a_rls_probe_%';

  insert into public.conservation_feature_flags
    (organization_id, site_id, flag_key, enabled)
  values
    (v_org, v_hq, 'p1a_rls_probe_hq', false),
    (v_org, v_osman, 'p1a_rls_probe_osman', false),
    (v_org, v_ali, 'p1a_rls_probe_ali', false),
    (v_org, v_arwa, 'p1a_rls_probe_arwa', false),
    (v_org, null, 'p1a_rls_probe_org', false);

  -- VIEWER: HQ (+Osman) visible; Ali not in viewer site list for SELECT isolation
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  select exists(
    select 1 from public.conservation_feature_flags where flag_key = 'p1a_rls_probe_hq'
  ) into v_ok;
  if not v_ok then raise exception 'RLS FAIL viewer cannot see HQ flag'; end if;
  select exists(
    select 1 from public.conservation_feature_flags where flag_key = 'p1a_rls_probe_ali'
  ) into v_ok;
  if v_ok then raise exception 'RLS FAIL viewer saw Ali flag outside scope'; end if;
  begin
    insert into public.conservation_feature_flags
      (organization_id, site_id, flag_key, enabled)
    values (v_org, v_hq, 'p1a_rls_probe_viewer_write', false);
    raise exception 'RLS FAIL viewer was allowed to insert';
  exception
    when others then
      if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- TECHNICIAN: can SELECT Osman; cannot WRITE (role gate)
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  select exists(
    select 1 from public.conservation_feature_flags where flag_key = 'p1a_rls_probe_osman'
  ) into v_ok;
  if not v_ok then raise exception 'RLS FAIL technician cannot see Osman flag'; end if;
  update public.conservation_feature_flags
  set enabled = true
  where flag_key = 'p1a_rls_probe_osman';
  get diagnostics v_updated = row_count;
  if v_updated > 0 then
    raise exception 'RLS FAIL technician updated flag (row_count=%)', v_updated;
  end if;
  reset role;

  -- SITE ADMIN: update HQ ok; Arwa out of manage scope
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  set local role authenticated;
  update public.conservation_feature_flags
  set enabled = true
  where flag_key = 'p1a_rls_probe_hq';
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'RLS FAIL site_admin HQ update row_count=%', v_updated;
  end if;
  update public.conservation_feature_flags
  set enabled = true
  where flag_key = 'p1a_rls_probe_arwa';
  get diagnostics v_updated = row_count;
  if v_updated > 0 then
    raise exception 'RLS FAIL site_admin updated Arwa out of manage scope';
  end if;
  reset role;

  -- SUPER ADMIN: sees all probe rows via explicit is_super_admin()
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  select count(*) into v_cnt
  from public.conservation_feature_flags
  where flag_key like 'p1a_rls_probe_%';
  if v_cnt < 5 then
    raise exception 'RLS FAIL super_admin saw only % probe rows (need >=5)', v_cnt;
  end if;
  reset role;

  delete from public.conservation_feature_flags where flag_key like 'p1a_rls_probe_%';
end;
$$;

select 'P1A_RLS_RESULT=PASS' as result,
       (select count(*)::int from public.conservation_feature_flags) as remaining_flag_rows,
       (select coalesce(bool_or(enabled), false) from public.conservation_feature_flags) as any_enabled;
