-- Production hardening assertions.
do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and has_function_privilege('anon', p.oid, 'EXECUTE');
  if v_count <> 0 then
    raise exception 'anon can execute % SECURITY DEFINER functions', v_count;
  end if;

  select count(*) into v_count
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r','p')
    and (
      has_table_privilege('anon', c.oid, 'SELECT')
      or has_table_privilege('anon', c.oid, 'INSERT')
      or has_table_privilege('anon', c.oid, 'UPDATE')
      or has_table_privilege('anon', c.oid, 'DELETE')
    );
  if v_count <> 0 then
    raise exception 'anon retains DML/SELECT privileges on % public tables', v_count;
  end if;

  if has_function_privilege(
    'authenticated',
    'public.utility_connect_ports_unlocked(uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,jsonb,boolean)'::regprocedure,
    'EXECUTE'
  ) then
    raise exception 'authenticated can directly execute utility_connect_ports_unlocked';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.utility_clone_revision_content(uuid,uuid)'::regprocedure,
    'EXECUTE'
  ) then
    raise exception 'authenticated can directly execute utility_clone_revision_content';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_select_own'
      and roles::text like '%public%'
  ) then
    raise exception 'profiles_select_own still targets PUBLIC';
  end if;
end
$$;
