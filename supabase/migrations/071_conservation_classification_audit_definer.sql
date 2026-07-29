-- 071: Audit insert via SECURITY DEFINER so authenticated need only SELECT on audit.
-- Additive REPLACE. No DROP of tables. No 056–062 repair.
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
