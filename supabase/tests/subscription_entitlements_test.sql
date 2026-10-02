-- Step 3 subscription/entitlement contract assertions.
do $$
declare v_org uuid; v_sites bigint; v_meters bigint; v_users bigint; v_max_sites int; v_max_meters int; v_max_users int;
begin
 select id into v_org from public.organizations order by created_at limit 1;
 if v_org is null then raise exception 'subscription test requires an organization'; end if;
 select count(*) into v_sites from public.sites where organization_id=v_org and is_active=true;
 select count(*) into v_meters from public.meters m join public.sites s on s.id=m.site_id where s.organization_id=v_org and m.is_active=true;
 select count(distinct user_id) into v_users from public.user_scope_assignments where organization_id=v_org and status='active';
 select max_sites,max_meters,max_users into v_max_sites,v_max_meters,v_max_users from public.organization_subscriptions where organization_id=v_org;
 if v_max_sites < v_sites or v_max_meters < v_meters or v_max_users < v_users then raise exception 'launch entitlement locks out existing tenant'; end if;
 if has_table_privilege('anon','public.organization_subscriptions','SELECT') then raise exception 'anon can read subscriptions'; end if;
 if has_table_privilege('authenticated','public.organization_subscriptions','UPDATE') then raise exception 'client can update billing state'; end if;
 if has_table_privilege('authenticated','public.subscription_plan_catalog','UPDATE') then raise exception 'client can update catalog'; end if;
 if has_function_privilege('anon','public.subscription_access_state(uuid)','EXECUTE') then raise exception 'anon can query entitlement RPC'; end if;
end $$;

do $$ begin
 if not exists(select 1 from public.subscription_plan_catalog where plan='professional' and features->>'conservation_mv'='true') then raise exception 'professional conservation entitlement missing'; end if;
 if not exists(select 1 from public.subscription_plan_catalog where plan='business' and features->>'automation'='true') then raise exception 'business automation entitlement missing'; end if;
end $$;
