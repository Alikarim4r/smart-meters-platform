-- Prevent arbitrary authenticated callers from probing baseline history through a SECURITY DEFINER allocator.
create or replace function public.conservation_baselines_next_version(p_site_id uuid, p_scope_type text, p_scope_id uuid, p_unit_code text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_next integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode='42501'; end if;
  if not (public.is_super_admin() or public.is_platform_owner() or public.conservation_site_admin_manages(p_site_id)) then
    raise exception 'Not allowed to allocate baseline version' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(coalesce(p_site_id::text,'')||'|'||coalesce(p_scope_type,'')||'|'||coalesce(p_scope_id::text,'')||'|'||coalesce(p_unit_code,''),0));
  select coalesce(max(version_number),0)+1 into v_next from public.conservation_baselines
  where site_id=p_site_id and scope_type=p_scope_type and unit_code=p_unit_code
    and ((p_scope_id is null and scope_id is null) or scope_id=p_scope_id);
  return v_next;
end;
$$;
revoke execute on function public.conservation_baselines_next_version(uuid,text,uuid,text) from public, anon;
grant execute on function public.conservation_baselines_next_version(uuid,text,uuid,text) to authenticated;
