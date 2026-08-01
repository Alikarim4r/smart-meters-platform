-- =============================================================================
-- 099: Authenticated API batch ingestion RPC (no public/anon endpoint)
-- Idempotent via external_reading_id / source_system. Conflicts → review table.
-- =============================================================================

create table if not exists public.api_ingestion_idempotency (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  source_system text not null,
  idempotency_key text not null,
  request_fingerprint text,
  response_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint api_ingestion_idempotency_uq unique (organization_id, source_system, idempotency_key)
);

alter table public.api_ingestion_idempotency enable row level security;
revoke all on table public.api_ingestion_idempotency from anon, authenticated;
grant select, insert on table public.api_ingestion_idempotency to authenticated;

create policy "api_ingestion_idempotency_select"
  on public.api_ingestion_idempotency for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "api_ingestion_idempotency_insert"
  on public.api_ingestion_idempotency for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create or replace function public.ingest_readings_batch(
  p_organization_id uuid,
  p_source_system text,
  p_source_type text,
  p_idempotency_key text,
  p_items jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_existing jsonb;
  v_item jsonb;
  v_results jsonb := '[]'::jsonb;
  v_accepted int := 0;
  v_rejected int := 0;
  v_duplicated int := 0;
  v_conflicts int := 0;
  v_meter_id uuid;
  v_site_id uuid;
  v_reading_date date;
  v_raw numeric;
  v_external_id text;
  v_existing_reading record;
  v_new_id uuid;
  v_idx int := 0;
  v_quality text;
  v_unit text;
  v_ts timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.user_can_manage_organization(p_organization_id)
  ) then
    raise exception 'Not authorized for organization ingestion';
  end if;

  if p_source_type not in (
    'api', 'smart_meter', 'bms', 'iot', 'csv_import', 'excel_import'
  ) then
    raise exception 'Invalid source_type for API ingestion';
  end if;

  if p_idempotency_key is not null and length(trim(p_idempotency_key)) > 0 then
    select response_payload into v_existing
    from public.api_ingestion_idempotency
    where organization_id = p_organization_id
      and source_system = p_source_system
      and idempotency_key = p_idempotency_key;
    if found then
      return v_existing;
    end if;
  end if;

  if jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a JSON array';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_idx := v_idx + 1;
    begin
      v_meter_id := nullif(v_item->>'meter_id', '')::uuid;
      v_site_id := nullif(v_item->>'site_id', '')::uuid;
      v_reading_date := (v_item->>'reading_date')::date;
      v_raw := (v_item->>'raw_value')::numeric;
      v_external_id := nullif(v_item->>'external_reading_id', '');
      v_quality := coalesce(nullif(v_item->>'source_quality', ''), 'unknown');
      v_unit := nullif(v_item->>'unit_code', '');
      v_ts := nullif(v_item->>'source_timestamp', '')::timestamptz;

      if v_meter_id is null or v_site_id is null or v_reading_date is null or v_raw is null then
        v_rejected := v_rejected + 1;
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'index', v_idx,
          'status', 'rejected',
          'error', 'missing_required_fields'
        ));
        continue;
      end if;

      if not public.can_manage_site(v_site_id) and not public.is_super_admin()
         and not public.is_platform_owner()
         and not public.user_can_manage_organization(p_organization_id) then
        v_rejected := v_rejected + 1;
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'index', v_idx,
          'status', 'rejected',
          'error', 'site_unauthorized'
        ));
        continue;
      end if;

      -- Idempotent external id
      if v_external_id is not null then
        select id into v_new_id
        from public.meter_readings
        where source_system = p_source_system
          and external_reading_id = v_external_id
        limit 1;
        if found then
          v_duplicated := v_duplicated + 1;
          v_results := v_results || jsonb_build_array(jsonb_build_object(
            'index', v_idx,
            'status', 'duplicated',
            'reading_id', v_new_id
          ));
          continue;
        end if;
      end if;

      select * into v_existing_reading
      from public.meter_readings
      where meter_id = v_meter_id and reading_date = v_reading_date
      limit 1;

      if found then
        if v_existing_reading.raw_value = v_raw then
          v_duplicated := v_duplicated + 1;
          v_results := v_results || jsonb_build_array(jsonb_build_object(
            'index', v_idx,
            'status', 'duplicated',
            'reading_id', v_existing_reading.id,
            'conflict_kind', 'duplicate_identical'
          ));
        else
          insert into public.reading_source_conflicts (
            organization_id, site_id, meter_id, reading_date,
            existing_reading_id, incoming_source, incoming_raw_value,
            incoming_payload, existing_raw_value, existing_source,
            conflict_kind, status
          ) values (
            p_organization_id, v_site_id, v_meter_id, v_reading_date,
            v_existing_reading.id, p_source_type, v_raw,
            v_item, v_existing_reading.raw_value, v_existing_reading.reading_source,
            case
              when coalesce(v_existing_reading.reading_source, 'legacy') in ('manual', 'manual_photo', 'legacy')
                then 'manual_vs_automated'
              else 'differing_values'
            end,
            'pending_review'
          );
          v_conflicts := v_conflicts + 1;
          v_results := v_results || jsonb_build_array(jsonb_build_object(
            'index', v_idx,
            'status', 'conflict',
            'error', 'requires_review',
            'existing_reading_id', v_existing_reading.id
          ));
        end if;
        continue;
      end if;

      insert into public.meter_readings (
        site_id, meter_id, reading_date, raw_value,
        reading_source, source_system, external_reading_id,
        source_timestamp, received_at, source_quality,
        original_raw_value, original_unit_code, is_canonical,
        entered_by
      ) values (
        v_site_id, v_meter_id, v_reading_date, v_raw,
        p_source_type, p_source_system, v_external_id,
        v_ts, now(), v_quality,
        v_raw, v_unit, true,
        auth.uid()
      )
      returning id into v_new_id;

      v_accepted := v_accepted + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'index', v_idx,
        'status', 'accepted',
        'reading_id', v_new_id
      ));
    exception when others then
      v_rejected := v_rejected + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'index', v_idx,
        'status', 'rejected',
        'error', SQLERRM
      ));
    end;
  end loop;

  v_existing := jsonb_build_object(
    'accepted', v_accepted,
    'rejected', v_rejected,
    'duplicated', v_duplicated,
    'conflicts', v_conflicts,
    'results', v_results
  );

  if p_idempotency_key is not null and length(trim(p_idempotency_key)) > 0 then
    insert into public.api_ingestion_idempotency (
      organization_id, source_system, idempotency_key, response_payload
    ) values (
      p_organization_id, p_source_system, p_idempotency_key, v_existing
    )
    on conflict (organization_id, source_system, idempotency_key) do nothing;
  end if;

  insert into public.platform_integration_audit (
    organization_id, actor_id, action_type, entity_type, details
  ) values (
    p_organization_id, auth.uid(), 'api_ingest_batch', 'meter_readings', v_existing
  );

  return v_existing;
end;
$$;

revoke all on function public.ingest_readings_batch(uuid, text, text, text, jsonb) from public, anon;
grant execute on function public.ingest_readings_batch(uuid, text, text, text, jsonb) to authenticated;

comment on function public.ingest_readings_batch is
  'Authenticated batch reading ingestion. No anon access. Idempotent. Conflicts require review.';
