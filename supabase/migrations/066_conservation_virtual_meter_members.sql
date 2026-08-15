-- =============================================================================
-- 066: Conservation virtual meter members (P1E)
-- Additive only. Physical meter rows / parent_meter_id hierarchy unchanged.
-- Members link virtual meters to contributors WITHOUT mutating physical
-- parent_meter_id (physical hierarchy remains main→sub→sub_sub).
-- Existing reading-rejection triggers for virtual meters remain authoritative.
-- Explicit OR is_super_admin() / is_platform_owner() (062 has_site_access gap).
-- =============================================================================

create table if not exists public.conservation_virtual_meter_members (
  id uuid primary key default gen_random_uuid(),
  virtual_meter_id uuid not null references public.meters (id) on delete cascade,
  member_meter_id uuid not null references public.meters (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint conservation_vm_members_no_self check (virtual_meter_id <> member_meter_id),
  constraint conservation_vm_members_unique unique (virtual_meter_id, member_meter_id)
);

comment on table public.conservation_virtual_meter_members is
  'Children/contributors for virtual meters. Does not alter physical meters.parent_meter_id.';

create index if not exists conservation_vm_members_virtual_idx
  on public.conservation_virtual_meter_members (virtual_meter_id);

create index if not exists conservation_vm_members_member_idx
  on public.conservation_virtual_meter_members (member_meter_id);

-- Validate member rows: virtual must be virtual; same site; no physical parent rewrite.
create or replace function public.conservation_vm_members_validate()
returns trigger
language plpgsql
as $$
declare
  v_virtual record;
  v_member record;
begin
  select m.id, m.site_id, m.meter_kind, m.calculation_type, s.organization_id
  into v_virtual
  from public.meters m
  join public.sites s on s.id = m.site_id
  where m.id = new.virtual_meter_id;

  if not found then
    raise exception 'Virtual meter % not found', new.virtual_meter_id;
  end if;

  if v_virtual.meter_kind <> 'virtual' then
    raise exception 'conservation_virtual_meter_members.virtual_meter_id must be meter_kind=virtual';
  end if;

  if v_virtual.calculation_type not in ('sum_children', 'parent_minus_children') then
    raise exception 'Virtual meter calculation_type must be sum_children or parent_minus_children';
  end if;

  select m.id, m.site_id, m.meter_kind, s.organization_id
  into v_member
  from public.meters m
  join public.sites s on s.id = m.site_id
  where m.id = new.member_meter_id;

  if not found then
    raise exception 'Member meter % not found', new.member_meter_id;
  end if;

  if v_member.site_id <> v_virtual.site_id then
    raise exception 'Virtual meter members must be on the same site (cross-site rejected)';
  end if;

  if v_member.organization_id <> v_virtual.organization_id then
    raise exception 'Virtual meter members must be in the same organization';
  end if;

  return new;
end;
$$;

drop trigger if exists conservation_vm_members_validate_trg
  on public.conservation_virtual_meter_members;
create trigger conservation_vm_members_validate_trg
  before insert or update on public.conservation_virtual_meter_members
  for each row execute function public.conservation_vm_members_validate();

-- Additive cycle guard on meters.parent_meter_id (physical + virtual parent ref).
-- Does not change existing level rules; only walks ancestors.
create or replace function public.conservation_meters_reject_parent_cycle()
returns trigger
language plpgsql
as $$
declare
  v_walk uuid;
  v_depth int := 0;
begin
  if new.parent_meter_id is null then
    return new;
  end if;
  if new.parent_meter_id = new.id then
    raise exception 'Meter cannot be its own parent';
  end if;

  v_walk := new.parent_meter_id;
  while v_walk is not null loop
    v_depth := v_depth + 1;
    if v_depth > 32 then
      raise exception 'Meter parent hierarchy depth exceeded';
    end if;
    if v_walk = new.id then
      raise exception 'Meter parent hierarchy cycle detected';
    end if;
    select parent_meter_id into v_walk from public.meters where id = v_walk;
  end loop;
  return new;
end;
$$;

drop trigger if exists conservation_meters_reject_parent_cycle_trg on public.meters;
create trigger conservation_meters_reject_parent_cycle_trg
  before insert or update of parent_meter_id on public.meters
  for each row execute function public.conservation_meters_reject_parent_cycle();

alter table public.conservation_virtual_meter_members enable row level security;

revoke all on table public.conservation_virtual_meter_members from anon;
revoke all on table public.conservation_virtual_meter_members from authenticated;
grant select, insert, update, delete on table public.conservation_virtual_meter_members to authenticated;

create policy "conservation_vm_members_select"
  on public.conservation_virtual_meter_members
  for select
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.has_site_access(
      (select site_id from public.meters where id = virtual_meter_id)
    )
  );

create policy "conservation_vm_members_insert"
  on public.conservation_virtual_meter_members
  for insert
  to authenticated
  with check (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(
        (select site_id from public.meters where id = virtual_meter_id)
      )
    )
  );

create policy "conservation_vm_members_update"
  on public.conservation_virtual_meter_members
  for update
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(
        (select site_id from public.meters where id = virtual_meter_id)
      )
    )
  )
  with check (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(
        (select site_id from public.meters where id = virtual_meter_id)
      )
    )
  );

create policy "conservation_vm_members_delete"
  on public.conservation_virtual_meter_members
  for delete
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(
        (select site_id from public.meters where id = virtual_meter_id)
      )
    )
  );
