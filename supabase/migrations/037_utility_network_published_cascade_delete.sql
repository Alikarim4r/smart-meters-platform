-- 037: Allow cascade delete of published revisions when parent network is removed.
-- Content remains immutable for INSERT/UPDATE and direct DELETE while network exists.

create or replace function public.prevent_published_revision_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_rev uuid;
begin
  if tg_table_name = 'site_utility_network_revisions' then
    if tg_op = 'DELETE' then
      if old.status = 'published'
         and exists (
           select 1 from public.site_utility_networks n where n.id = old.network_id
         ) then
        raise exception 'Published revision is immutable';
      end if;
      return old;
    end if;
    if old.status = 'published' and (
         new.status is distinct from old.status
      or new.lock_version is distinct from old.lock_version
      or new.network_id is distinct from old.network_id
      or new.based_on_revision_id is distinct from old.based_on_revision_id
      or new.notes is distinct from old.notes
    ) then
      raise exception 'Published revision is immutable';
    end if;
    return new;
  end if;

  v_rev := coalesce(new.revision_id, old.revision_id);
  select status into v_status
  from public.site_utility_network_revisions where id = v_rev;

  -- Parent revision already removed (network/revision cascade): allow cleanup.
  if v_status is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    raise exception 'Revision not found for utility network content';
  end if;

  if v_status = 'published' then
    raise exception 'Published revision content is immutable';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

comment on function public.prevent_published_revision_mutation() is
  'Blocks mutations to published revision content; allows cascade deletes after parent network removal.';
