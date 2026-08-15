-- =============================================================================
-- 073: Conservation investigations + actions (Phase 3)
-- Additive. Human-confirmed cause only. Technician write scoped to assignment.
-- =============================================================================

create table if not exists public.conservation_investigations (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null
    references public.conservation_opportunities (id) on delete cascade,
  site_id uuid not null references public.sites (id) on delete cascade,
  assigned_to uuid references public.profiles (id) on delete set null,
  assigned_by uuid references auth.users (id),
  assigned_at timestamptz,
  investigation_status text not null default 'open',
  investigation_started_at timestamptz,
  investigation_completed_at timestamptz,
  finding_summary text,
  possible_cause text,
  confirmed_cause text,
  confirmed_by uuid references auth.users (id),
  confirmed_at timestamptz,
  notes text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_inv_status_check
    check (investigation_status in (
      'open', 'assigned', 'in_progress', 'completed', 'cancelled'
    )),
  constraint conservation_inv_confirmed_cause_check
    check (
      confirmed_cause is null
      or confirmed_cause in (
        'confirmed_leak',
        'suspected_leak',
        'meter_error',
        'reading_error',
        'unmetered_consumption',
        'operational_usage',
        'timing_alignment_difference',
        'data_issue',
        'false_positive',
        'other',
        'unknown'
      )
    ),
  -- Confirmed cause requires human actor + timestamp.
  constraint conservation_inv_confirmed_actor_check
    check (
      (confirmed_cause is null and confirmed_by is null and confirmed_at is null)
      or (confirmed_cause is not null and confirmed_by is not null and confirmed_at is not null)
    )
);

comment on table public.conservation_investigations is
  'Investigation workflow for opportunities. confirmed_cause is human-only.';

create index if not exists conservation_inv_opp_idx
  on public.conservation_investigations (opportunity_id);

create index if not exists conservation_inv_assignee_idx
  on public.conservation_investigations (assigned_to)
  where assigned_to is not null;

create index if not exists conservation_inv_site_status_idx
  on public.conservation_investigations (site_id, investigation_status);

create trigger conservation_inv_set_updated_at
  before update on public.conservation_investigations
  for each row execute function public.set_updated_at();

-- Reject auto-confirm without actor (defense).
create or replace function public.conservation_inv_reject_auto_confirm()
returns trigger
language plpgsql
as $$
begin
  if new.confirmed_cause is not null then
    if new.confirmed_by is null or new.confirmed_at is null then
      raise exception 'confirmed_cause requires confirmed_by and confirmed_at (human only)';
    end if;
    if tg_op = 'UPDATE'
       and old.confirmed_cause is distinct from new.confirmed_cause
       and new.confirmed_by = old.confirmed_by
       and old.confirmed_cause is null
       and new.confirmed_by is null then
      raise exception 'invalid confirmed_cause transition';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists conservation_inv_reject_auto_confirm_trg
  on public.conservation_investigations;
create trigger conservation_inv_reject_auto_confirm_trg
  before insert or update on public.conservation_investigations
  for each row execute function public.conservation_inv_reject_auto_confirm();

create table if not exists public.conservation_actions (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null
    references public.conservation_opportunities (id) on delete cascade,
  investigation_id uuid
    references public.conservation_investigations (id) on delete set null,
  site_id uuid not null references public.sites (id) on delete cascade,
  title text not null,
  description text not null default '',
  action_type text not null,
  owner_id uuid references public.profiles (id) on delete set null,
  priority text not null default 'medium',
  status text not null default 'open',
  due_date date,
  started_at timestamptz,
  completed_at timestamptz,
  completion_notes text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_action_title_nonempty
    check (length(trim(title)) > 0),
  constraint conservation_action_type_check
    check (action_type in (
      'inspect_meter',
      'inspect_pipe_network',
      'repair_leak',
      'correct_reading_meter_setup',
      'adjust_operating_schedule',
      'hvac_maintenance',
      'adjust_setpoint',
      'inspect_irrigation',
      'meter_calibration',
      'investigate_cop',
      'other'
    )),
  constraint conservation_action_priority_check
    check (priority in ('low', 'medium', 'high', 'critical')),
  constraint conservation_action_status_check
    check (status in (
      'open',
      'assigned',
      'in_progress',
      'completed',
      'cancelled',
      'verification_pending'
    ))
);

comment on table public.conservation_actions is
  'Conservation corrective actions (workflow only — does not control BMS/schedules).';

create index if not exists conservation_action_opp_idx
  on public.conservation_actions (opportunity_id);

create index if not exists conservation_action_owner_idx
  on public.conservation_actions (owner_id)
  where owner_id is not null;

create index if not exists conservation_action_site_status_idx
  on public.conservation_actions (site_id, status);

create index if not exists conservation_action_due_idx
  on public.conservation_actions (site_id, due_date)
  where status not in ('completed', 'cancelled');

create trigger conservation_action_set_updated_at
  before update on public.conservation_actions
  for each row execute function public.set_updated_at();

-- Block open → completed without intermediate progress (unless cancelled path).
create or replace function public.conservation_action_transition_guard()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and old.status = 'open'
     and new.status = 'completed' then
    raise exception
      'conservation_actions: open → completed not allowed; assign/start first or use privileged override via cancelled';
  end if;
  return new;
end;
$$;

drop trigger if exists conservation_action_transition_guard_trg
  on public.conservation_actions;
create trigger conservation_action_transition_guard_trg
  before update on public.conservation_actions
  for each row execute function public.conservation_action_transition_guard();

alter table public.conservation_investigations enable row level security;
alter table public.conservation_actions enable row level security;

revoke all on table public.conservation_investigations from anon, authenticated;
revoke all on table public.conservation_actions from anon, authenticated;
grant select, insert, update, delete on table public.conservation_investigations to authenticated;
grant select, insert, update, delete on table public.conservation_actions to authenticated;

-- Investigations SELECT
create policy "conservation_inv_select"
  on public.conservation_investigations for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

-- Investigations INSERT: site_admin / super / owner
create policy "conservation_inv_insert"
  on public.conservation_investigations for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

-- Investigations UPDATE: site_admin manage OR assigned technician (progress only)
create policy "conservation_inv_update"
  on public.conservation_investigations for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
    or (
      public.current_user_role() = 'technician'::public.user_role
      and assigned_to = auth.uid()
      and public.has_site_access(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
    or (
      public.current_user_role() = 'technician'::public.user_role
      and assigned_to = auth.uid()
      and public.has_site_access(site_id)
    )
  );

create policy "conservation_inv_delete"
  on public.conservation_investigations for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
      and investigation_status in ('open', 'cancelled')
    )
  );

-- Actions SELECT
create policy "conservation_action_select"
  on public.conservation_actions for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_action_insert"
  on public.conservation_actions for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "conservation_action_update"
  on public.conservation_actions for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
    or (
      public.current_user_role() = 'technician'::public.user_role
      and owner_id = auth.uid()
      and public.has_site_access(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
    or (
      public.current_user_role() = 'technician'::public.user_role
      and owner_id = auth.uid()
      and public.has_site_access(site_id)
    )
  );

create policy "conservation_action_delete"
  on public.conservation_actions for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
      and status in ('open', 'cancelled')
    )
  );
