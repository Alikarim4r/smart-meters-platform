-- =============================================================================
-- 069: Balance classification + minimum audit (Phase 2)
-- Human-reviewed only. Confirmed Leak is NEVER auto-assigned by DB/app defaults.
-- Additive. No meter_readings changes.
-- =============================================================================

create table if not exists public.conservation_balance_classifications (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  balance_group_id uuid not null
    references public.conservation_balance_groups (id) on delete cascade,
  period_start date not null,
  period_end date not null,
  classification text not null,
  notes text,
  evidence_refs jsonb not null default '[]'::jsonb,
  balance_difference numeric(18, 4),
  unit_code text,
  classified_by uuid references auth.users (id),
  classified_at timestamptz not null default now(),
  previous_classification text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_balance_class_period_check
    check (period_end >= period_start),
  constraint conservation_balance_class_value_check
    check (
      classification in (
        'confirmed_leak',
        'suspected_leak',
        'meter_error',
        'reading_error',
        'unmetered_consumption',
        'operational_usage',
        'timing_alignment_difference',
        'unknown'
      )
    )
);

comment on table public.conservation_balance_classifications is
  'Human-reviewed Balance Difference classification. Confirmed Leak must never be auto-set.';

create unique index if not exists conservation_balance_class_period_uq
  on public.conservation_balance_classifications (
    balance_group_id, period_start, period_end
  );

create index if not exists conservation_balance_class_site_idx
  on public.conservation_balance_classifications (site_id);

create table if not exists public.conservation_balance_classification_audit (
  id uuid primary key default gen_random_uuid(),
  classification_id uuid not null
    references public.conservation_balance_classifications (id) on delete cascade,
  changed_by uuid references auth.users (id),
  changed_at timestamptz not null default now(),
  previous_classification text,
  new_classification text not null,
  notes text,
  evidence_refs jsonb not null default '[]'::jsonb
);

comment on table public.conservation_balance_classification_audit is
  'Minimum safe audit trail for balance classification changes.';

create index if not exists conservation_balance_class_audit_class_idx
  on public.conservation_balance_classification_audit (classification_id);

create trigger conservation_balance_class_set_updated_at
  before update on public.conservation_balance_classifications
  for each row execute function public.set_updated_at();

create or replace function public.conservation_balance_class_audit_insert_fn()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.conservation_balance_classification_audit (
    classification_id, changed_by, previous_classification,
    new_classification, notes, evidence_refs
  ) values (
    new.id, new.classified_by, null,
    new.classification, new.notes, new.evidence_refs
  );
  return new;
end;
$$;

create or replace function public.conservation_balance_class_audit_update_fn()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.classification is distinct from old.classification
     or new.notes is distinct from old.notes
     or new.evidence_refs is distinct from old.evidence_refs then
    new.previous_classification := old.classification;
    new.classified_at := now();
    insert into public.conservation_balance_classification_audit (
      classification_id, changed_by, previous_classification,
      new_classification, notes, evidence_refs
    ) values (
      new.id, new.classified_by, old.classification,
      new.classification, new.notes, new.evidence_refs
    );
  end if;
  return new;
end;
$$;

revoke all on function public.conservation_balance_class_audit_insert_fn() from public;
revoke all on function public.conservation_balance_class_audit_update_fn() from public;
grant execute on function public.conservation_balance_class_audit_insert_fn() to authenticated;
grant execute on function public.conservation_balance_class_audit_update_fn() to authenticated;

drop trigger if exists conservation_balance_class_audit_insert_trg
  on public.conservation_balance_classifications;
create trigger conservation_balance_class_audit_insert_trg
  after insert on public.conservation_balance_classifications
  for each row execute function public.conservation_balance_class_audit_insert_fn();

drop trigger if exists conservation_balance_class_audit_update_trg
  on public.conservation_balance_classifications;
create trigger conservation_balance_class_audit_update_trg
  before update on public.conservation_balance_classifications
  for each row execute function public.conservation_balance_class_audit_update_fn();

alter table public.conservation_balance_classifications enable row level security;
alter table public.conservation_balance_classification_audit enable row level security;

revoke all on table public.conservation_balance_classifications from anon, authenticated;
revoke all on table public.conservation_balance_classification_audit from anon, authenticated;
grant select, insert, update, delete on table public.conservation_balance_classifications to authenticated;
grant select on table public.conservation_balance_classification_audit to authenticated;

create policy "conservation_balance_class_select"
  on public.conservation_balance_classifications for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_balance_class_insert"
  on public.conservation_balance_classifications for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "conservation_balance_class_update"
  on public.conservation_balance_classifications for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "conservation_balance_class_delete"
  on public.conservation_balance_classifications for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "conservation_balance_class_audit_select"
  on public.conservation_balance_classification_audit for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(
      (select site_id from public.conservation_balance_classifications c
       where c.id = classification_id)
    )
  );
