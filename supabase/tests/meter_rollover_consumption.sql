begin;
select plan(5);

-- Setup test data
insert into public.organizations (id, name_en, name_ar) values ('00000000-0000-0000-0000-000000000001', 'Test Org', 'Test Org Ar');
insert into public.sites (id, organization_id, name_en, name_ar, site_type) values ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Test Site', 'Test Site Ar', 'other');

-- Meter 1: Normal meter (no rollover)
insert into public.meters (id, site_id, meter_code, name_en, name_ar, category, unit, unit_to_base_factor, base_unit, meter_multiplier) 
values ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 'M1', 'M1', 'M1', 'water', 'm3', 1, 'm3', 1);

-- Meter 2: Meter with rollover capacity of 10000
insert into public.meters (id, site_id, meter_code, name_en, name_ar, category, unit, unit_to_base_factor, base_unit, meter_multiplier, rollover_capacity) 
values ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', 'M2', 'M2', 'M2', 'water', 'm3', 1, 'm3', 1, 10000);

-- Insert readings for M1
insert into public.meter_readings (meter_id, site_id, reading_date, raw_value, normalized_value)
values 
  ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', '2023-01-01', 9990, 9990),
  ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', '2023-01-02', 10, 10); -- Unverifiable drop (no rollover capacity)

-- Insert readings for M2
insert into public.meter_readings (meter_id, site_id, reading_date, raw_value, normalized_value)
values 
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', '2023-01-01', 9990, 9990),
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', '2023-01-02', 10, 10); -- Verifiable rollover

-- Assertions
select is(
  (select daily_consumption from public.meter_daily_consumption where meter_id = '00000000-0000-0000-0000-000000000003' and reading_date = '2023-01-01'),
  0::numeric,
  'First reading gives 0 consumption'
);

select is(
  (select daily_consumption from public.meter_daily_consumption where meter_id = '00000000-0000-0000-0000-000000000003' and reading_date = '2023-01-02'),
  null::numeric,
  'Unverifiable drop gives null consumption'
);

select is(
  (select daily_consumption from public.meter_daily_consumption where meter_id = '00000000-0000-0000-0000-000000000004' and reading_date = '2023-01-02'),
  20::numeric, -- (10000 - 9990) + 10 = 20
  'Rollover correctly calculates consumption'
);

-- Also verify normal increasing consumption on M2
insert into public.meter_readings (meter_id, site_id, reading_date, raw_value, normalized_value)
values 
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', '2023-01-03', 15, 15);

select is(
  (select daily_consumption from public.meter_daily_consumption where meter_id = '00000000-0000-0000-0000-000000000004' and reading_date = '2023-01-03'),
  5::numeric,
  'Normal increasing reading gives direct difference'
);

-- Verify the is_rollover flag
select is(
  (select is_rollover from public.meter_daily_consumption where meter_id = '00000000-0000-0000-0000-000000000004' and reading_date = '2023-01-02'),
  true,
  'Rollover flag is true for verifiable rollover'
);

select * from finish();
rollback;
