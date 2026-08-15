-- =============================================================================
-- 080: Action implementation cost fields (Phase 4)
-- Additive columns on conservation_actions. Missing cost → ROI/Payback N/A.
-- =============================================================================

alter table public.conservation_actions
  add column if not exists implementation_cost numeric(18, 4);

alter table public.conservation_actions
  add column if not exists cost_currency text;

alter table public.conservation_actions
  add column if not exists cost_source text;

alter table public.conservation_actions
  add column if not exists cost_approved boolean not null default false;

alter table public.conservation_actions
  drop constraint if exists conservation_action_impl_cost_nonneg;
alter table public.conservation_actions
  add constraint conservation_action_impl_cost_nonneg
  check (implementation_cost is null or implementation_cost >= 0);

comment on column public.conservation_actions.implementation_cost is
  'Real implementation cost for ROI/Payback. Never invent. Null → financial N/A.';
