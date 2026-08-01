-- =============================================================================
-- 096: In-app notifications, preferences, dedupe fingerprints
-- Data Availability Alert terminology (not Equipment Fault).
-- =============================================================================

create table if not exists public.in_app_notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete cascade,
  notification_type text not null,
  severity text not null default 'info',
  title text not null,
  body text not null,
  event_key text not null,
  related_entity_type text,
  related_entity_id uuid,
  payload jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  read_at timestamptz,
  generated_at timestamptz not null default now(),
  expires_at timestamptz,
  constraint in_app_notifications_severity_check
    check (severity in ('info', 'warning', 'critical')),
  constraint in_app_notifications_type_check
    check (notification_type in (
      'import_completed',
      'import_failed',
      'source_delayed',
      'data_availability',
      'action_overdue',
      'verification_ready',
      'saving_not_sustained',
      'forecast_target_exceedance',
      'data_quality_review',
      'automation_suggestion',
      'ai_suggestion',
      'conflict_pending'
    ))
);

-- Deduplicate: same event_key for same user (or org broadcast) within active window
create unique index if not exists in_app_notifications_user_event_uq
  on public.in_app_notifications (user_id, event_key)
  where user_id is not null;

create unique index if not exists in_app_notifications_org_event_uq
  on public.in_app_notifications (organization_id, event_key)
  where user_id is null;

create index if not exists in_app_notifications_user_unread_idx
  on public.in_app_notifications (user_id, is_read, generated_at desc)
  where user_id is not null;

create index if not exists in_app_notifications_org_idx
  on public.in_app_notifications (organization_id, generated_at desc);

comment on table public.in_app_notifications is
  'In-app notification center. Deduped by event_key. No WhatsApp/Email in Phase 6.';

create table if not exists public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  notification_type text not null,
  min_severity text not null default 'info',
  site_id uuid references public.sites (id) on delete cascade,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_preferences_severity_check
    check (min_severity in ('info', 'warning', 'critical'))
);

create unique index if not exists notification_preferences_uq
  on public.notification_preferences (
    user_id,
    organization_id,
    notification_type,
    (coalesce(site_id, '00000000-0000-0000-0000-000000000000'::uuid))
  );

create trigger notification_preferences_set_updated_at
  before update on public.notification_preferences
  for each row execute function public.set_updated_at();

comment on table public.notification_preferences is
  'Per-user notification preferences. Avoid noisy per-reading alerts.';

-- Data availability alerts (expected reading not received ≠ equipment fault)
create table if not exists public.data_availability_alerts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid not null references public.sites (id) on delete cascade,
  meter_id uuid references public.meters (id) on delete set null,
  data_source_id uuid references public.external_data_sources (id) on delete set null,
  alert_key text not null,
  expected_by timestamptz not null,
  status text not null default 'open',
  message text not null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint data_availability_alerts_status_check
    check (status in ('open', 'resolved', 'suppressed'))
);

create unique index if not exists data_availability_alerts_open_key_uq
  on public.data_availability_alerts (organization_id, alert_key)
  where status = 'open';

comment on table public.data_availability_alerts is
  'Data Availability Alert — expected reading not received. NEVER labeled Equipment Fault.';

alter table public.in_app_notifications enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.data_availability_alerts enable row level security;

revoke all on table public.in_app_notifications from anon, authenticated;
revoke all on table public.notification_preferences from anon, authenticated;
revoke all on table public.data_availability_alerts from anon, authenticated;

grant select, insert, update, delete on table public.in_app_notifications to authenticated;
grant select, insert, update, delete on table public.notification_preferences to authenticated;
grant select, insert, update, delete on table public.data_availability_alerts to authenticated;

create policy "in_app_notifications_select"
  on public.in_app_notifications for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or user_id = auth.uid()
    or (
      user_id is null
      and (
        public.user_can_manage_organization(organization_id)
        or (site_id is not null and public.has_site_access(site_id))
      )
    )
  );

create policy "in_app_notifications_insert"
  on public.in_app_notifications for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "in_app_notifications_update"
  on public.in_app_notifications for update to authenticated
  using (
    user_id = auth.uid()
    or public.is_super_admin() or public.is_platform_owner()
  )
  with check (
    user_id = auth.uid()
    or public.is_super_admin() or public.is_platform_owner()
  );

create policy "notification_preferences_select"
  on public.notification_preferences for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_super_admin() or public.is_platform_owner()
  );

create policy "notification_preferences_write"
  on public.notification_preferences for all to authenticated
  using (
    user_id = auth.uid()
    or public.is_super_admin() or public.is_platform_owner()
  )
  with check (
    user_id = auth.uid()
    or public.is_super_admin() or public.is_platform_owner()
  );

create policy "data_availability_alerts_select"
  on public.data_availability_alerts for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "data_availability_alerts_write"
  on public.data_availability_alerts for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );
