-- =============================================================================
-- 115: Enforce reading policy and correction workflow on the server.
--
-- Additive hardening only:
--   * no existing meter_readings or audit rows are rewritten;
--   * technician inserts enforce effective photo/date/cutoff policy;
--   * admin value/note corrections must use a reason-bearing RPC;
--   * photo-only admin updates remain supported.
-- =============================================================================

-- New values must be HH:MM or HH:MM:SS. Existing legacy values are retained
-- by NOT VALID and are treated as "no cutoff" until an admin saves a valid one.
alter table public.policy_settings
  drop constraint if exists policy_settings_daily_cutoff_format_check;
alter table public.policy_settings
  add constraint policy_settings_daily_cutoff_format_check
  check (
    daily_reading_cutoff_time is null
    or daily_reading_cutoff_time ~
      '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$'
  ) not valid;

create or replace function public.effective_reading_policy(p_site_id uuid)
returns table (
  photo_required boolean,
  daily_cutoff time without time zone,
  allow_late_readings boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with selected_policy as (
    select
      coalesce(site_policy.photo_required, org_policy.photo_required, false)
        as photo_required,
      coalesce(
        site_policy.daily_reading_cutoff_time,
        org_policy.daily_reading_cutoff_time
      ) as daily_cutoff_text,
      coalesce(
        site_policy.allow_late_readings,
        org_policy.allow_late_readings,
        false
      ) as allow_late_readings
    from public.sites s
    left join lateral (
      select ps.photo_required,
             ps.daily_reading_cutoff_time,
             ps.allow_late_readings
      from public.policy_settings ps
      where ps.site_id = s.id
        and ps.scope = 'site'
        and ps.is_active = true
      order by ps.updated_at desc, ps.id desc
      limit 1
    ) site_policy on true
    left join lateral (
      select ps.photo_required,
             ps.daily_reading_cutoff_time,
             ps.allow_late_readings
      from public.policy_settings ps
      where ps.organization_id = s.organization_id
        and ps.scope = 'organization'
        and ps.site_id is null
        and ps.is_active = true
      order by ps.updated_at desc, ps.id desc
      limit 1
    ) org_policy on true
    where s.id = p_site_id
  )
  select
    selected_policy.photo_required,
    case
      when selected_policy.daily_cutoff_text ~
        '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$'
        then selected_policy.daily_cutoff_text::time
      else null
    end,
    selected_policy.allow_late_readings
  from selected_policy;
$$;

revoke all on function public.effective_reading_policy(uuid) from public;
revoke all on function public.effective_reading_policy(uuid)
  from anon, authenticated;

create or replace function public.technician_reading_policy_allows(
  p_site_id uuid,
  p_reading_date date,
  p_image_url text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_policy record;
  v_business_date date := public.current_business_date();
  v_qatar_time time without time zone :=
    (statement_timestamp() at time zone 'Asia/Qatar')::time;
begin
  select * into v_policy
  from public.effective_reading_policy(p_site_id);

  if not found or p_reading_date is null then
    return false;
  end if;

  if v_policy.photo_required
     and nullif(trim(coalesce(p_image_url, '')), '') is null then
    return false;
  end if;

  if p_reading_date > v_business_date then
    return false;
  end if;

  if p_reading_date < v_business_date then
    return v_policy.allow_late_readings
      and public.can_backdate_readings();
  end if;

  if v_policy.daily_cutoff is not null
     and v_qatar_time > v_policy.daily_cutoff then
    return v_policy.allow_late_readings;
  end if;

  return true;
end;
$$;

revoke all on function public.technician_reading_policy_allows(uuid, date, text)
  from public;
grant execute on function public.technician_reading_policy_allows(uuid, date, text)
  to authenticated;

-- RLS mirrors the trigger below so PostgREST cannot bypass operational policy.
drop policy if exists "meter_readings_insert_technician"
  on public.meter_readings;
create policy "meter_readings_insert_technician"
  on public.meter_readings for insert
  to authenticated
  with check (
    public.is_technician_only_for_site(site_id)
    and entered_by = auth.uid()
    and public.technician_reading_policy_allows(
      site_id,
      reading_date,
      image_url
    )
    and exists (
      select 1
      from public.meters m
      where m.id = meter_id
        and m.site_id = meter_readings.site_id
        and m.is_active = true
        and m.meter_kind = 'physical'
        and m.calculation_type = 'direct_reading'
    )
  );

create or replace function public.validate_technician_reading_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site_id uuid;
  v_meter record;
  v_policy record;
  v_business_date date := public.current_business_date();
  v_qatar_time time without time zone :=
    (statement_timestamp() at time zone 'Asia/Qatar')::time;
begin
  v_site_id := coalesce(new.site_id, old.site_id);

  if not public.is_technician_only_for_site(v_site_id) then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    select * into v_policy
    from public.effective_reading_policy(v_site_id);

    if not found then
      raise exception 'Site policy could not be resolved';
    end if;

    if new.reading_date > v_business_date then
      raise exception
        'Readings cannot be dated in the future (Asia/Qatar business date: %)',
        v_business_date;
    end if;

    if new.reading_date < v_business_date
       and not (
         v_policy.allow_late_readings
         and public.can_backdate_readings()
       ) then
      raise exception
        'Backdated readings require both organization late-reading policy and per-user backdating permission';
    end if;

    if new.reading_date = v_business_date
       and v_policy.daily_cutoff is not null
       and v_qatar_time > v_policy.daily_cutoff
       and not v_policy.allow_late_readings then
      raise exception
        'Daily reading cutoff has passed (Asia/Qatar cutoff: %)',
        v_policy.daily_cutoff;
    end if;

    if v_policy.photo_required
       and nullif(trim(coalesce(new.image_url, '')), '') is null then
      raise exception 'A meter photo is required by the effective site policy';
    end if;

    if new.entered_by is distinct from auth.uid() then
      raise exception 'Technicians cannot set entered_by to another user';
    end if;

    select site_id, meter_kind, calculation_type, is_active
    into v_meter
    from public.meters
    where id = new.meter_id;

    if not found then
      raise exception 'Meter not found';
    end if;

    if v_meter.meter_kind <> 'physical'
       or v_meter.calculation_type <> 'direct_reading' then
      raise exception 'Technicians can only submit readings for physical meters';
    end if;

    if not v_meter.is_active then
      raise exception 'Technicians can only submit readings for active meters';
    end if;

    if v_meter.site_id <> new.site_id then
      raise exception 'Meter must belong to the reading site';
    end if;

    return new;
  elsif tg_op = 'UPDATE' then
    raise exception
      'Technicians cannot modify saved readings. Contact a site admin for correction.';
  elsif tg_op = 'DELETE' then
    raise exception
      'Technicians cannot delete readings. Contact a site admin for correction.';
  end if;

  return coalesce(new, old);
end;
$$;

-- Admin value/note/date identity changes must go through a reason-bearing RPC.
-- Service-role maintenance (auth.uid() is null) is deliberately left available.
create or replace function public.protect_meter_reading_correction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if current_setting('app.reading_correction_rpc', true) = '1' then
    return new;
  end if;

  if new.raw_value is distinct from old.raw_value
     or new.note is distinct from old.note
     or new.reading_date is distinct from old.reading_date
     or new.meter_id is distinct from old.meter_id
     or new.site_id is distinct from old.site_id then
    raise exception
      'Reading value/note corrections must use admin_correct_meter_reading with a reason';
  end if;

  return new;
end;
$$;

drop trigger if exists meter_readings_b1_protect_correction
  on public.meter_readings;
create trigger meter_readings_b1_protect_correction
  before update on public.meter_readings
  for each row execute function public.protect_meter_reading_correction();

revoke all on function public.protect_meter_reading_correction() from public;
revoke all on function public.protect_meter_reading_correction()
  from anon, authenticated;

create or replace function public.admin_correct_meter_reading(
  p_reading_id uuid,
  p_new_raw_value numeric,
  p_new_note text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reading public.meter_readings%rowtype;
  v_updated public.meter_readings%rowtype;
  v_reason text := trim(coalesce(p_reason, ''));
  v_note text := nullif(trim(coalesce(p_new_note, '')), '');
  v_allowed_reasons constant text[] := array[
    'wrongReading',
    'duplicateMistake',
    'meterPhotoMismatch',
    'technicianMistake',
    'clientRequest',
    'abnormalConsumption',
    'other'
  ];
begin
  if p_new_raw_value is null or p_new_raw_value < 0 then
    raise exception 'Corrected reading value must be zero or greater';
  end if;

  if not (v_reason = any(v_allowed_reasons)) then
    raise exception 'A valid correction reason is required';
  end if;

  select * into v_reading
  from public.meter_readings
  where id = p_reading_id
  for update;

  if not found then
    raise exception 'Reading not found';
  end if;

  if not public.is_admin_for_site(v_reading.site_id) then
    raise exception 'Only super_admin or site_admin can correct readings';
  end if;

  if p_new_raw_value = v_reading.raw_value
     and v_note is not distinct from v_reading.note then
    raise exception 'No reading value or note change to save';
  end if;

  if v_note is null
     or v_note not like ('[CORRECTION:' || v_reason || ']%') then
    v_note := '[CORRECTION:' || v_reason || ']'
      || case when v_note is null then '' else ' ' || v_note end;
  end if;

  perform set_config('app.reading_correction_rpc', '1', true);

  update public.meter_readings mr
  set raw_value = p_new_raw_value,
      note = v_note
  where mr.id = p_reading_id
  returning mr.* into v_updated;

  perform set_config('app.reading_correction_rpc', '0', true);

  return jsonb_build_object(
    'id', v_updated.id,
    'raw_value', v_updated.raw_value,
    'note', v_updated.note,
    'updated_at', v_updated.updated_at
  );
end;
$$;

revoke all on function public.admin_correct_meter_reading(
  uuid,
  numeric,
  text,
  text
) from public;
grant execute on function public.admin_correct_meter_reading(
  uuid,
  numeric,
  text,
  text
) to authenticated;

comment on function public.admin_correct_meter_reading(uuid, numeric, text, text)
  is 'Admin-only reading correction RPC. Requires a reason and preserves the existing append-only audit trigger.';
