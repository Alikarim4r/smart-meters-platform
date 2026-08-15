-- =============================================================================
-- 074: Conservation evidence + append-only workflow audit (Phase 3)
-- =============================================================================

create table if not exists public.conservation_evidence (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  opportunity_id uuid
    references public.conservation_opportunities (id) on delete cascade,
  investigation_id uuid
    references public.conservation_investigations (id) on delete cascade,
  action_id uuid
    references public.conservation_actions (id) on delete cascade,
  evidence_kind text not null,
  -- before | after | general — Phase 4 M&V can use before/after later.
  evidence_phase text not null default 'general',
  title text not null default '',
  notes text,
  storage_bucket text,
  storage_path text,
  external_url text,
  meter_reading_id uuid,
  reference_json jsonb not null default '{}'::jsonb,
  uploaded_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  constraint conservation_evidence_kind_check
    check (evidence_kind in (
      'photo',
      'note',
      'meter_reading_reference',
      'balance_result_reference',
      'anomaly_reference',
      'document_link'
    )),
  constraint conservation_evidence_phase_check
    check (evidence_phase in ('before', 'after', 'general')),
  constraint conservation_evidence_parent_check
    check (
      opportunity_id is not null
      or investigation_id is not null
      or action_id is not null
    )
);

comment on table public.conservation_evidence is
  'Conservation workflow evidence. Separate from meter-images reading photos when using conservation-evidence bucket.';

create index if not exists conservation_evidence_site_idx
  on public.conservation_evidence (site_id);

create index if not exists conservation_evidence_opp_idx
  on public.conservation_evidence (opportunity_id)
  where opportunity_id is not null;

create index if not exists conservation_evidence_inv_idx
  on public.conservation_evidence (investigation_id)
  where investigation_id is not null;

create index if not exists conservation_evidence_action_idx
  on public.conservation_evidence (action_id)
  where action_id is not null;

-- Append-only workflow audit. Clients cannot UPDATE/DELETE.
create table if not exists public.conservation_workflow_audit (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  actor_id uuid references auth.users (id),
  action text not null,
  from_status text,
  to_status text,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint conservation_wf_audit_entity_check
    check (entity_type in ('opportunity', 'investigation', 'action', 'evidence'))
);

comment on table public.conservation_workflow_audit is
  'Append-only conservation workflow audit. No client UPDATE/DELETE.';

create index if not exists conservation_wf_audit_entity_idx
  on public.conservation_workflow_audit (entity_type, entity_id);

create index if not exists conservation_wf_audit_site_idx
  on public.conservation_workflow_audit (site_id, created_at desc);

-- SECURITY DEFINER helper to append audit (callers need EXECUTE only).
create or replace function public.conservation_workflow_audit_append(
  p_site_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_action text,
  p_from_status text default null,
  p_to_status text default null,
  p_notes text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.conservation_workflow_audit (
    site_id, entity_type, entity_id, actor_id, action,
    from_status, to_status, notes, metadata
  ) values (
    p_site_id, p_entity_type, p_entity_id, auth.uid(), p_action,
    p_from_status, p_to_status, p_notes, coalesce(p_metadata, '{}'::jsonb)
  ) returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.conservation_workflow_audit_append(
  uuid, text, uuid, text, text, text, text, jsonb
) from public;
grant execute on function public.conservation_workflow_audit_append(
  uuid, text, uuid, text, text, text, text, jsonb
) to authenticated;

alter table public.conservation_evidence enable row level security;
alter table public.conservation_workflow_audit enable row level security;

revoke all on table public.conservation_evidence from anon, authenticated;
revoke all on table public.conservation_workflow_audit from anon, authenticated;
grant select, insert, update, delete on table public.conservation_evidence to authenticated;
grant select on table public.conservation_workflow_audit to authenticated;
-- No INSERT/UPDATE/DELETE grant for authenticated on audit (definer fn only).

create policy "conservation_evidence_select"
  on public.conservation_evidence for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

-- Upload: site_admin manage OR technician with site access who is assignee/owner
-- of related investigation/action (or opportunity in-scope with assignment).
create policy "conservation_evidence_insert"
  on public.conservation_evidence for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
    or (
      public.current_user_role() = 'technician'::public.user_role
      and public.has_site_access(site_id)
      and (
        (
          investigation_id is not null
          and exists (
            select 1 from public.conservation_investigations i
            where i.id = investigation_id
              and i.assigned_to = auth.uid()
          )
        )
        or (
          action_id is not null
          and exists (
            select 1 from public.conservation_actions a
            where a.id = action_id
              and a.owner_id = auth.uid()
          )
        )
        or (
          opportunity_id is not null
          and exists (
            select 1 from public.conservation_investigations i
            where i.opportunity_id = opportunity_id
              and i.assigned_to = auth.uid()
          )
        )
      )
    )
  );

create policy "conservation_evidence_update"
  on public.conservation_evidence for update to authenticated
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

create policy "conservation_evidence_delete"
  on public.conservation_evidence for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "conservation_wf_audit_select"
  on public.conservation_workflow_audit for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );
