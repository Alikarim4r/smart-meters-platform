-- =============================================================================
-- Smart Meters Platform — Policy Settings
-- Migration: 010_policy_settings.sql
-- Status: DRAFT — review before applying to staging/production
-- Depends on: 001_schema.sql, 005_user_approval.sql
-- =============================================================================

create table if not exists public.policy_settings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  scope text not null default 'organization',
  site_id uuid references public.sites (id) on delete cascade,
  photo_required boolean not null default false,
  missing_photo_severity text not null default 'info',
  high_consumption_multiplier numeric(8, 2) not null default 3.0,
  high_consumption_critical_multiplier numeric(8, 2) not null default 5.0,
  zero_consumption_alert_enabled boolean not null default true,
  low_completion_warning_percent numeric(5, 2) not null default 80,
  low_completion_critical_percent numeric(5, 2) not null default 50,
  low_cop_warning_threshold numeric(8, 2) not null default 2.5,
  low_cop_critical_threshold numeric(8, 2) not null default 2.0,
  cop_missing_data_alert_enabled boolean not null default true,
  possible_leak_days_warning integer not null default 2,
  possible_leak_days_critical integer not null default 3,
  daily_reading_cutoff_time text,
  allow_late_readings boolean not null default false,
  report_footer_text text,
  organization_display_name text,
  logo_url text,
  include_alert_section_default boolean not null default true,
  include_photo_indicator_default boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint policy_settings_scope_check
    check (scope in ('organization', 'site')),
  constraint policy_settings_missing_photo_severity_check
    check (missing_photo_severity in ('info', 'warning', 'critical')),
  constraint policy_settings_high_consumption_multiplier_positive
    check (high_consumption_multiplier > 0),
  constraint policy_settings_high_consumption_critical_multiplier_positive
    check (high_consumption_critical_multiplier > 0),
  constraint policy_settings_low_completion_warning_percent_range
    check (low_completion_warning_percent > 0 and low_completion_warning_percent <= 100),
  constraint policy_settings_low_completion_critical_percent_range
    check (low_completion_critical_percent > 0 and low_completion_critical_percent <= 100),
  constraint policy_settings_low_cop_warning_threshold_positive
    check (low_cop_warning_threshold > 0),
  constraint policy_settings_low_cop_critical_threshold_positive
    check (low_cop_critical_threshold > 0),
  constraint policy_settings_possible_leak_days_warning_positive
    check (possible_leak_days_warning > 0),
  constraint policy_settings_possible_leak_days_critical_positive
    check (possible_leak_days_critical > 0),
  constraint policy_settings_site_scope_requires_site_id
    check (
      (scope = 'organization' and site_id is null)
      or (scope = 'site' and site_id is not null)
    )
);

create unique index if not exists policy_settings_org_active_unique_idx
  on public.policy_settings (organization_id)
  where scope = 'organization' and site_id is null and is_active = true;

create index if not exists policy_settings_organization_id_idx
  on public.policy_settings (organization_id);

create index if not exists policy_settings_site_id_idx
  on public.policy_settings (site_id)
  where site_id is not null;

comment on table public.policy_settings is
  'Organization/site operational policy for readings, photos, alerts, reports, and branding.';

create trigger policy_settings_set_updated_at
  before update on public.policy_settings
  for each row execute function public.set_updated_at();

alter table public.policy_settings enable row level security;

revoke insert, update, delete on public.policy_settings from anon;

create policy "policy_settings_select"
  on public.policy_settings for select
  to authenticated
  using (
    public.is_super_admin()
    or exists (
      select 1
      from public.sites s
      join public.user_site_access usa on usa.site_id = s.id
      join public.profiles p on p.id = usa.user_id
      where s.organization_id = policy_settings.organization_id
        and usa.user_id = auth.uid()
        and usa.can_read = true
        and p.is_active = true
    )
  );

create policy "policy_settings_insert"
  on public.policy_settings for insert
  to authenticated
  with check (public.is_super_admin());

create policy "policy_settings_update"
  on public.policy_settings for update
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

create policy "policy_settings_delete"
  on public.policy_settings for delete
  to authenticated
  using (public.is_super_admin());
