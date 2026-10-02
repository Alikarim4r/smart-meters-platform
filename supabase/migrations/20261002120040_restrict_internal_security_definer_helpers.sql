-- Restrict internal SECURITY DEFINER helpers that are not client RPCs.
-- Public wrappers and policy helpers retain authenticated EXECUTE.

revoke execute on function public.utility_check_draft_lock(uuid, integer)
  from authenticated;
revoke execute on function public.utility_link_meter_neighbors(
  uuid, uuid, uuid, uuid[], text, text, text, boolean
) from authenticated;
revoke execute on function public.utility_legacy_writes_frozen(uuid, uuid)
  from authenticated;
revoke execute on function public.utility_require_auth()
  from authenticated;
