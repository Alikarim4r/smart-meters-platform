-- Phase validation for policy_settings migration (010).
-- Run after applying 010_policy_settings.sql on staging.

\set ON_ERROR_STOP on

do $$
declare
  v_count int;
begin
  if to_regclass('public.policy_settings') is null then
    raise exception 'policy_settings table missing — apply 010_policy_settings.sql first';
  end if;
end $$;

-- RLS enabled
select relrowsecurity
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'policy_settings';

-- Default row can be inserted by super_admin only (manual check in app)
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'policy_settings'
order by ordinal_position;

-- Unique active organization policy
select indexname
from pg_indexes
where schemaname = 'public'
  and tablename = 'policy_settings'
  and indexname = 'policy_settings_org_active_unique_idx';

-- Policies exist
select policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename = 'policy_settings'
order by policyname;

-- Constraint smoke: invalid severity rejected
do $$
begin
  begin
    insert into public.policy_settings (
      organization_id,
      missing_photo_severity
    )
    select id, 'invalid'
    from public.organizations
    limit 1;
    raise exception 'constraint test failed: invalid severity was accepted';
  exception
    when check_violation then
      raise notice 'OK: invalid missing_photo_severity rejected';
  end;
end $$;

select 'policy_settings validation script loaded' as status;
