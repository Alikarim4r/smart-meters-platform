-- Smart Meters B2B subscription and entitlement foundation.
-- Provider-neutral and server-authoritative. No payment provider is trusted here.

create type public.subscription_plan as enum ('trial','starter','professional','business','enterprise');
create type public.subscription_status as enum ('trialing','active','past_due','grace_period','canceled','expired');
create type public.billing_provider as enum ('manual','google_play','external_contract');

create table public.subscription_plan_catalog (
  plan public.subscription_plan primary key,
  display_order integer not null,
  monthly_price_qar integer,
  annual_price_qar integer,
  trial_days integer not null default 0 check (trial_days >= 0),
  max_users integer not null check (max_users > 0),
  max_sites integer not null check (max_sites > 0),
  max_meters integer not null check (max_meters > 0),
  is_public boolean not null default true,
  is_recommended boolean not null default false,
  features jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.subscription_plan_catalog
(plan,display_order,monthly_price_qar,annual_price_qar,trial_days,max_users,max_sites,max_meters,is_public,is_recommended,features)
values
('trial',0,0,0,30,10,1,50,false,false,'{"dashboard":true,"reading_entry":true,"reports":true}'::jsonb),
('starter',1,null,null,0,10,1,50,true,false,'{"dashboard":true,"reading_entry":true,"reports":true}'::jsonb),
('professional',2,null,null,0,50,10,500,true,true,'{"dashboard":true,"reading_entry":true,"reports":true,"advanced_reports":true,"conservation_mv":true,"api_ingestion":true}'::jsonb),
('business',3,null,null,0,200,50,5000,true,false,'{"dashboard":true,"reading_entry":true,"reports":true,"advanced_reports":true,"conservation_mv":true,"api_ingestion":true,"automation":true,"priority_support":true}'::jsonb),
('enterprise',4,null,null,0,1000000,1000000,1000000,true,false,'{"dashboard":true,"reading_entry":true,"reports":true,"advanced_reports":true,"conservation_mv":true,"api_ingestion":true,"automation":true,"priority_support":true,"custom_limits":true,"sla":true,"onboarding":true}'::jsonb);

create table public.organization_subscriptions (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  plan public.subscription_plan not null default 'trial',
  status public.subscription_status not null default 'trialing',
  provider public.billing_provider not null default 'manual',
  provider_customer_ref text,
  provider_subscription_ref text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  grace_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  max_users integer not null check (max_users > 0),
  max_sites integer not null check (max_sites > 0),
  max_meters integer not null check (max_meters > 0),
  features jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index organization_subscriptions_provider_ref_uidx
  on public.organization_subscriptions(provider,provider_subscription_ref)
  where provider_subscription_ref is not null;
create trigger organization_subscriptions_set_updated_at before update on public.organization_subscriptions
  for each row execute function public.set_updated_at();

alter table public.subscription_plan_catalog enable row level security;
alter table public.organization_subscriptions enable row level security;
create policy subscription_plan_catalog_read on public.subscription_plan_catalog for select to authenticated using (true);
create policy organization_subscriptions_select on public.organization_subscriptions for select to authenticated
  using (public.is_platform_owner() or public.user_can_manage_organization(organization_id)
    or exists (select 1 from public.sites s where s.organization_id=organization_subscriptions.organization_id and public.has_site_access(s.id)));
revoke all on public.subscription_plan_catalog, public.organization_subscriptions from anon;
revoke insert,update,delete on public.subscription_plan_catalog, public.organization_subscriptions from authenticated;
grant select on public.subscription_plan_catalog, public.organization_subscriptions to authenticated;

create or replace function public.subscription_access_state(p_organization_id uuid)
returns table(plan public.subscription_plan,status public.subscription_status,has_access boolean,max_users integer,max_sites integer,max_meters integer,current_period_end timestamptz,grace_period_end timestamptz,features jsonb)
language sql stable security invoker set search_path='' as $$
 select s.plan,s.status,
   (s.status in ('trialing','active','grace_period') and (s.status<>'grace_period' or s.grace_period_end is null or s.grace_period_end>now())),
   s.max_users,s.max_sites,s.max_meters,s.current_period_end,s.grace_period_end,s.features
 from public.organization_subscriptions s
 where s.organization_id=p_organization_id and (
   public.is_platform_owner() or public.user_can_manage_organization(p_organization_id)
   or exists(select 1 from public.sites si where si.organization_id=p_organization_id and public.has_site_access(si.id)))
 limit 1;
$$;
revoke execute on function public.subscription_access_state(uuid) from public,anon;
grant execute on function public.subscription_access_state(uuid) to authenticated;

create or replace function public.subscription_has_feature(p_organization_id uuid,p_feature text)
returns boolean language sql stable security definer set search_path=public as $$
 select coalesce(exists(
   select 1 from public.organization_subscriptions s
   where s.organization_id=p_organization_id
     and s.status in ('trialing','active','grace_period')
     and (s.status<>'grace_period' or s.grace_period_end is null or s.grace_period_end>now())
     and coalesce((s.features->>p_feature)::boolean,false)
 ),false);
$$;
revoke execute on function public.subscription_has_feature(uuid,text) from public,anon;
grant execute on function public.subscription_has_feature(uuid,text) to authenticated;

create or replace function public.subscription_usage(p_organization_id uuid)
returns table(active_users bigint,active_sites bigint,active_meters bigint,max_users integer,max_sites integer,max_meters integer)
language sql stable security invoker set search_path='' as $$
 select
   (select count(distinct usa.user_id) from public.user_scope_assignments usa where usa.organization_id=p_organization_id and usa.status='active'),
   (select count(*) from public.sites si where si.organization_id=p_organization_id and si.is_active=true),
   (select count(*) from public.meters m join public.sites si on si.id=m.site_id where si.organization_id=p_organization_id and m.is_active=true),
   s.max_users,s.max_sites,s.max_meters
 from public.organization_subscriptions s
 where s.organization_id=p_organization_id and (
   public.is_platform_owner() or public.user_can_manage_organization(p_organization_id)
   or exists(select 1 from public.sites si where si.organization_id=p_organization_id and public.has_site_access(si.id)))
 limit 1;
$$;
revoke execute on function public.subscription_usage(uuid) from public,anon;
grant execute on function public.subscription_usage(uuid) to authenticated;

create or replace function public.enforce_subscription_site_limit() returns trigger
language plpgsql security definer set search_path=public as $$
declare s public.organization_subscriptions%rowtype; n bigint;
begin
 if new.is_active is not true then return new; end if;
 select * into s from public.organization_subscriptions where organization_id=new.organization_id;
 if not found then raise exception 'SUBSCRIPTION_REQUIRED'; end if;
 if s.status not in ('trialing','active','grace_period') then raise exception 'SUBSCRIPTION_INACTIVE'; end if;
 if s.status='grace_period' and s.grace_period_end is not null and s.grace_period_end<=now() then raise exception 'SUBSCRIPTION_EXPIRED'; end if;
 select count(*) into n from public.sites where organization_id=new.organization_id and is_active=true and id<>new.id;
 if n>=s.max_sites then raise exception 'SUBSCRIPTION_SITE_LIMIT_REACHED:%',s.max_sites; end if;
 return new;
end; $$;
create trigger enforce_subscription_site_limit before insert or update of is_active,organization_id on public.sites
for each row execute function public.enforce_subscription_site_limit();

create or replace function public.enforce_subscription_meter_limit() returns trigger
language plpgsql security definer set search_path=public as $$
declare s public.organization_subscriptions%rowtype; v_org uuid; n bigint;
begin
 if new.is_active is not true then return new; end if;
 select organization_id into v_org from public.sites where id=new.site_id;
 select * into s from public.organization_subscriptions where organization_id=v_org;
 if not found then raise exception 'SUBSCRIPTION_REQUIRED'; end if;
 if s.status not in ('trialing','active','grace_period') then raise exception 'SUBSCRIPTION_INACTIVE'; end if;
 if s.status='grace_period' and s.grace_period_end is not null and s.grace_period_end<=now() then raise exception 'SUBSCRIPTION_EXPIRED'; end if;
 select count(*) into n from public.meters m join public.sites si on si.id=m.site_id
  where si.organization_id=v_org and m.is_active=true and m.id<>new.id;
 if n>=s.max_meters then raise exception 'SUBSCRIPTION_METER_LIMIT_REACHED:%',s.max_meters; end if;
 return new;
end; $$;
create trigger enforce_subscription_meter_limit before insert or update of is_active,site_id on public.meters
for each row execute function public.enforce_subscription_meter_limit();

-- Preserve all existing production organizations during the provider-neutral rollout.
insert into public.organization_subscriptions
(organization_id,plan,status,provider,current_period_start,current_period_end,max_users,max_sites,max_meters,features)
select o.id,'professional','active','manual',now(),now()+interval '365 days',50,10,500,
 '{"dashboard":true,"reading_entry":true,"reports":true,"advanced_reports":true,"conservation_mv":true,"api_ingestion":true}'::jsonb
from public.organizations o
on conflict(organization_id) do nothing;

-- Billing state remains server-owned. Platform owner is authorization, not entitlement.
comment on table public.organization_subscriptions is
 'Server-authoritative organization subscription state. Payment providers are evidence sources, never the authorization source.';
