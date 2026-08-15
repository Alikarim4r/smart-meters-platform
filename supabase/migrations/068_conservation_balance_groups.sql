-- =============================================================================
-- 068: Conservation balance groups (Phase 2)
-- Additive. Organizes Main − Σ Submeters Balance Difference.
-- May optionally link to a P1E virtual meter (parent_minus_children).
-- Does NOT mutate physical parent_meter_id or meter_readings.
-- =============================================================================

create table if not exists public.conservation_balance_groups (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  name text not null,
  utility_code text not null,
  unit_code text not null,
  main_meter_id uuid not null references public.meters (id) on delete restrict,
  virtual_meter_id uuid references public.meters (id) on delete set null,
  status text not null default 'active',
  notes text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_balance_groups_name_nonempty
    check (length(trim(name)) > 0),
  constraint conservation_balance_groups_utility_check
    check (utility_code in ('water', 'electricity')),
  constraint conservation_balance_groups_unit_nonempty
    check (length(trim(unit_code)) > 0),
  constraint conservation_balance_groups_status_check
    check (status in ('draft', 'active', 'archived'))
);

comment on table public.conservation_balance_groups is
  'Balance Difference groups: Main − Σ children. Labels: Balance Difference / Unaccounted / Residual — never auto Leak.';

create table if not exists public.conservation_balance_group_members (
  id uuid primary key default gen_random_uuid(),
  balance_group_id uuid not null
    references public.conservation_balance_groups (id) on delete cascade,
  member_meter_id uuid not null references public.meters (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint conservation_bg_members_unique
    unique (balance_group_id, member_meter_id)
);

create index if not exists conservation_balance_groups_site_idx
  on public.conservation_balance_groups (site_id);

create index if not exists conservation_balance_groups_utility_idx
  on public.conservation_balance_groups (site_id, utility_code);

create index if not exists conservation_bg_members_group_idx
  on public.conservation_balance_group_members (balance_group_id);

create index if not exists conservation_bg_members_meter_idx
  on public.conservation_balance_group_members (member_meter_id);

create trigger conservation_balance_groups_set_updated_at
  before update on public.conservation_balance_groups
  for each row execute function public.set_updated_at();

-- Validate group + members: same site, unit consistency, main ≠ member.
create or replace function public.conservation_balance_group_validate()
returns trigger
language plpgsql
as $$
declare
  v_group record;
  v_main record;
  v_member record;
  v_virtual record;
begin
  if tg_table_name = 'conservation_balance_groups' then
    select m.id, m.site_id, m.meter_kind
      into v_main
    from public.meters m
    where m.id = new.main_meter_id;

    if not found then
      raise exception 'Main meter % not found', new.main_meter_id;
    end if;
    if v_main.site_id <> new.site_id then
      raise exception 'Main meter must belong to balance group site';
    end if;

    if new.virtual_meter_id is not null then
      select m.id, m.site_id, m.meter_kind, m.calculation_type
        into v_virtual
      from public.meters m
      where m.id = new.virtual_meter_id;
      if not found then
        raise exception 'Virtual meter % not found', new.virtual_meter_id;
      end if;
      if v_virtual.site_id <> new.site_id then
        raise exception 'Virtual meter must belong to balance group site';
      end if;
      if v_virtual.meter_kind <> 'virtual' then
        raise exception 'virtual_meter_id must reference meter_kind=virtual';
      end if;
      if v_virtual.calculation_type <> 'parent_minus_children' then
        raise exception 'Linked virtual meter must use parent_minus_children';
      end if;
    end if;
    return new;
  end if;

  -- members table
  select g.*, s.organization_id
    into v_group
  from public.conservation_balance_groups g
  join public.sites s on s.id = g.site_id
  where g.id = new.balance_group_id;

  if not found then
    raise exception 'Balance group % not found', new.balance_group_id;
  end if;

  if new.member_meter_id = v_group.main_meter_id then
    raise exception 'Member cannot be the main meter';
  end if;

  select m.id, m.site_id into v_member
  from public.meters m
  where m.id = new.member_meter_id;

  if not found then
    raise exception 'Member meter % not found', new.member_meter_id;
  end if;
  if v_member.site_id <> v_group.site_id then
    raise exception 'Balance members must be on the same site';
  end if;

  return new;
end;
$$;

drop trigger if exists conservation_balance_groups_validate_trg
  on public.conservation_balance_groups;
create trigger conservation_balance_groups_validate_trg
  before insert or update on public.conservation_balance_groups
  for each row execute function public.conservation_balance_group_validate();

drop trigger if exists conservation_bg_members_validate_trg
  on public.conservation_balance_group_members;
create trigger conservation_bg_members_validate_trg
  before insert or update on public.conservation_balance_group_members
  for each row execute function public.conservation_balance_group_validate();

alter table public.conservation_balance_groups enable row level security;
alter table public.conservation_balance_group_members enable row level security;

revoke all on table public.conservation_balance_groups from anon, authenticated;
revoke all on table public.conservation_balance_group_members from anon, authenticated;
grant select, insert, update, delete on table public.conservation_balance_groups to authenticated;
grant select, insert, update, delete on table public.conservation_balance_group_members to authenticated;

create policy "conservation_balance_groups_select"
  on public.conservation_balance_groups for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_balance_groups_insert"
  on public.conservation_balance_groups for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "conservation_balance_groups_update"
  on public.conservation_balance_groups for update to authenticated
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

create policy "conservation_balance_groups_delete"
  on public.conservation_balance_groups for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "conservation_bg_members_select"
  on public.conservation_balance_group_members for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(
      (select site_id from public.conservation_balance_groups where id = balance_group_id)
    )
  );

create policy "conservation_bg_members_insert"
  on public.conservation_balance_group_members for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(
        (select site_id from public.conservation_balance_groups where id = balance_group_id)
      )
    )
  );

create policy "conservation_bg_members_update"
  on public.conservation_balance_group_members for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(
        (select site_id from public.conservation_balance_groups where id = balance_group_id)
      )
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(
        (select site_id from public.conservation_balance_groups where id = balance_group_id)
      )
    )
  );

create policy "conservation_bg_members_delete"
  on public.conservation_balance_group_members for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(
        (select site_id from public.conservation_balance_groups where id = balance_group_id)
      )
    )
  );
