-- =============================================================================
-- 097: Automation rules (admin-only activate) + AI suggestion audit
-- No automatic confirmed diagnosis. No equipment control.
-- =============================================================================

create table if not exists public.automation_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete cascade,
  rule_key text not null,
  display_name text not null,
  rule_version int not null default 1,
  enabled boolean not null default false,
  trigger_config jsonb not null default '{}'::jsonb,
  action_config jsonb not null default '{}'::jsonb,
  explanation text not null,
  created_by uuid references public.profiles (id) on delete set null,
  activated_by uuid references public.profiles (id) on delete set null,
  activated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint automation_rules_key_nonempty
    check (length(trim(rule_key)) > 0)
);

create unique index if not exists automation_rules_org_key_version_uq
  on public.automation_rules (organization_id, rule_key, rule_version);

create trigger automation_rules_set_updated_at
  before update on public.automation_rules
  for each row execute function public.set_updated_at();

comment on table public.automation_rules is
  'Versioned, explainable automation rules. Admin-only activate. Idempotent suggestions only. No control.';

create table if not exists public.automation_rule_firings (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid not null references public.automation_rules (id) on delete cascade,
  firing_key text not null,
  status text not null default 'fired',
  result_payload jsonb not null default '{}'::jsonb,
  created_opportunity_id uuid,
  created_notification_id uuid,
  fired_at timestamptz not null default now(),
  constraint automation_rule_firings_status_check
    check (status in ('fired', 'suppressed', 'failed')),
  constraint automation_rule_firings_rule_key_uq unique (rule_id, firing_key)
);

comment on table public.automation_rule_firings is
  'Idempotent rule firings keyed by firing_key. Never auto-confirms diagnosis.';

create table if not exists public.ai_suggestion_audits (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete set null,
  user_id uuid references public.profiles (id) on delete set null,
  suggestion_type text not null,
  prompt_fingerprint text,
  input_references jsonb not null default '[]'::jsonb,
  output_text text not null,
  used_fallback boolean not null default false,
  model_name text,
  requires_human_review boolean not null default true,
  created_at timestamptz not null default now(),
  constraint ai_suggestion_audits_type_check
    check (suggestion_type in (
      'status_summary',
      'alert_explanation',
      'opportunity_summary',
      'investigation_checklist',
      'executive_summary_draft',
      'forecast_explanation',
      'priority_explanation',
      'missing_data_note',
      'smart_suggestion'
    ))
);

create index if not exists ai_suggestion_audits_org_idx
  on public.ai_suggestion_audits (organization_id, created_at desc);

comment on table public.ai_suggestion_audits is
  'AI-assisted suggestions with grounded references. Always requires human review. No protected mutations.';

create table if not exists public.platform_integration_audit (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  action_type text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists platform_integration_audit_org_idx
  on public.platform_integration_audit (organization_id, created_at desc);

comment on table public.platform_integration_audit is
  'Append-oriented audit for sources, imports, jobs, rules, conflicts, AI suggestions.';

-- Also update 097 function body historically for fresh applies: see 101.
create or replace function public.enforce_automation_rules_admin_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.user_role;
  v_sub text;
begin
  v_sub := nullif(current_setting('request.jwt.claim.sub', true), '');
  if v_sub is null then
    return new;
  end if;

  v_role := public.current_user_role();
  if v_role is null then
    raise exception 'Authentication required';
  end if;
  if v_role = 'technician'::public.user_role then
    raise exception 'Technicians cannot manage automation rules';
  end if;
  if v_role = 'viewer'::public.user_role then
    raise exception 'Viewers cannot manage automation rules';
  end if;
  if TG_OP = 'UPDATE' and new.enabled = true and coalesce(old.enabled, false) = false then
    if not (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.user_can_manage_organization(new.organization_id)
      or public.current_user_role() = 'site_admin'::public.user_role
    ) then
      raise exception 'Only admins can activate automation rules';
    end if;
    new.activated_by := auth.uid();
    new.activated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists automation_rules_admin_only on public.automation_rules;
create trigger automation_rules_admin_only
  before insert or update on public.automation_rules
  for each row execute function public.enforce_automation_rules_admin_only();

alter table public.automation_rules enable row level security;
alter table public.automation_rule_firings enable row level security;
alter table public.ai_suggestion_audits enable row level security;
alter table public.platform_integration_audit enable row level security;

revoke all on table public.automation_rules from anon, authenticated;
revoke all on table public.automation_rule_firings from anon, authenticated;
revoke all on table public.ai_suggestion_audits from anon, authenticated;
revoke all on table public.platform_integration_audit from anon, authenticated;

grant select, insert, update, delete on table public.automation_rules to authenticated;
grant select, insert, update, delete on table public.automation_rule_firings to authenticated;
grant select, insert on table public.ai_suggestion_audits to authenticated;
grant select, insert on table public.platform_integration_audit to authenticated;

create policy "automation_rules_select"
  on public.automation_rules for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      site_id is not null and public.has_site_access(site_id)
      and public.current_user_role() in (
        'site_admin'::public.user_role,
        'viewer'::public.user_role
      )
    )
  );

create policy "automation_rules_write"
  on public.automation_rules for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and (site_id is null or public.can_manage_site(site_id))
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and (site_id is null or public.can_manage_site(site_id))
    )
  );

create policy "automation_rule_firings_select"
  on public.automation_rule_firings for select to authenticated
  using (
    exists (
      select 1 from public.automation_rules r
      where r.id = automation_rule_firings.rule_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(r.organization_id)
        )
    )
  );

create policy "automation_rule_firings_write"
  on public.automation_rule_firings for all to authenticated
  using (
    exists (
      select 1 from public.automation_rules r
      where r.id = automation_rule_firings.rule_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(r.organization_id)
        )
    )
  )
  with check (
    exists (
      select 1 from public.automation_rules r
      where r.id = automation_rule_firings.rule_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(r.organization_id)
        )
    )
  );

create policy "ai_suggestion_audits_select"
  on public.ai_suggestion_audits for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or user_id = auth.uid()
  );

create policy "ai_suggestion_audits_insert"
  on public.ai_suggestion_audits for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or user_id = auth.uid()
  );

create policy "platform_integration_audit_select"
  on public.platform_integration_audit for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "platform_integration_audit_insert"
  on public.platform_integration_audit for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );
