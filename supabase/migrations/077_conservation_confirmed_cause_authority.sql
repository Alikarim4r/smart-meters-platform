-- =============================================================================
-- 077: Confirmed cause authority hardening (Phase 3 follow-up / Phase 4 prep)
-- Additive. Technicians propose; site_admin/super/owner confirm.
-- Does NOT rewrite 072–076. Forward-only.
-- =============================================================================

alter table public.conservation_investigations
  add column if not exists proposed_cause text;

comment on column public.conservation_investigations.proposed_cause is
  'Technician / investigator proposed cause. Distinct from human-approved confirmed_cause.';

comment on column public.conservation_investigations.confirmed_cause is
  'Human-approved confirmed cause. Writable only by site_admin (USA manage) / super_admin / platform_owner.';

create or replace function public.conservation_inv_confirmed_cause_authority()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.confirmed_cause is not null
       or new.confirmed_by is not null
       or new.confirmed_at is not null then
      if not (
        public.is_super_admin()
        or public.is_platform_owner()
        or public.conservation_site_admin_manages(new.site_id)
      ) then
        raise exception
          'confirmed_cause requires site_admin / super_admin / platform_owner (not technician)';
      end if;
    end if;
    return new;
  end if;

  if new.confirmed_cause is distinct from old.confirmed_cause
     or new.confirmed_by is distinct from old.confirmed_by
     or new.confirmed_at is distinct from old.confirmed_at then
    if not (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.conservation_site_admin_manages(new.site_id)
    ) then
      raise exception
        'confirmed_cause requires site_admin / super_admin / platform_owner (not technician)';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists conservation_inv_confirmed_cause_authority_trg
  on public.conservation_investigations;
create trigger conservation_inv_confirmed_cause_authority_trg
  before insert or update on public.conservation_investigations
  for each row execute function public.conservation_inv_confirmed_cause_authority();
