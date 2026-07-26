-- =============================================================================
-- Migration: 016_gj_unit_and_chw_reclassify.sql
-- Add legacy enum value `gj` in its own transaction.
-- (Postgres forbids using a newly added enum label in the same transaction.)
-- Catalog unit, sync, protect trigger, and admin_reclassify_meter live in 017.
-- =============================================================================

do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    where t.typname = 'meter_unit'
      and e.enumlabel = 'gj'
  ) then
    alter type public.meter_unit add value 'gj';
  end if;
end
$$;
