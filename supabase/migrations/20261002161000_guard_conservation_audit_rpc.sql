-- Guard append-only conservation audit RPC against arbitrary authenticated writes.
create or replace function public.conservation_workflow_audit_append(
  p_site_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_action text,
  p_from_status text default null,
  p_to_status text default null,
  p_notes text default null,
  p_metadata jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  if not (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.conservation_site_admin_manages(p_site_id)
  ) then
    raise exception 'Not allowed to append conservation workflow audit' using errcode = '42501';
  end if;
  if p_entity_type = 'opportunity' and not exists (
    select 1 from public.conservation_opportunities o
    where o.id = p_entity_id and o.site_id = p_site_id
  ) then
    raise exception 'Opportunity does not belong to site' using errcode = '23514';
  end if;
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
revoke execute on function public.conservation_workflow_audit_append(uuid,text,uuid,text,text,text,text,jsonb) from public, anon;
grant execute on function public.conservation_workflow_audit_append(uuid,text,uuid,text,text,text,text,jsonb) to authenticated;
