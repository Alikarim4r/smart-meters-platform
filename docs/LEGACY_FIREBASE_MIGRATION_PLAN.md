# Legacy Firebase → Supabase Migration Plan

**Source:** Frozen Firebase prototype (MOEHE HQ)  
**Target:** smart-meters-platform (Supabase)  
**Status:** Planning  
**Last updated:** 2026-07-03

---

## 1. Legacy Stack Summary

| Item | Value |
|------|-------|
| Firebase project | `water-meters-system` |
| Firestore appId | `electricity-meters-system` |
| Auth | Anonymous |
| Meter storage | SharedPreferences (`metersDefinitions_v1`) |
| Reading storage | Firestore date-keyed docs |
| Image storage | Firebase Storage `meter_images/{type}/{meterCode}/{date}.jpg` |
| Site model | Single site (MOEHE HQ), hardcoded seed |
| BTU/COP | Not implemented (BTU type exists, no data) |

**Legacy apps (frozen — do not modify):**
- `/Users/ali-laptop/Downloads/water_readings_app`
- `/Users/ali-laptop/Downloads/electricity_readings_app`
- `/Users/ali-laptop/Downloads/meters_dashboard_app`
- `/Users/ali-laptop/Downloads/meters_admin_app`

**Reference doc:** `/Users/ali-laptop/Downloads/meters-legacy-stack/STATUS.md`

---

## 2. Migration Goals

1. Preserve all historical readings and images from MOEHE HQ
2. Reconstruct full meter hierarchy in Supabase `meters` table
3. Map legacy meter codes to new UUID-based meters
4. Enable multi-site expansion without re-migrating MOEHE data
5. Leave legacy Firebase stack untouched as read-only archive

---

## 3. Data Mapping

### 3.1 Organization and Site

| Legacy | Supabase |
|--------|----------|
| (implicit single tenant) | `organizations`: MOEHE |
| MOEHE HQ campus | `sites`: MOEHE HQ, type `headquarters` |

Seed UUIDs defined in `supabase/seed/001_seed_moehe_hq.sql`.

### 3.2 Meters

Legacy meters live in SharedPreferences, not Firestore. Export source:

**Canonical seed:** `water_readings_app/lib/data/seed/seed_meters.dart`  
(Includes full tank topology; admin app seed is simplified/outdated.)

| Legacy field | Supabase column | Notes |
|--------------|-----------------|-------|
| `meterCode` | `meter_code` | Primary lookup key for migration |
| `displayEn` / `name` | `name_en` | |
| `displayAr` | `name_ar` | |
| `type` | `category` | water → water, electricity → electricity, btu → btu |
| `group` | `source` | kahramaa → kahramaa, ashghal → tse |
| `category` (main/sub) | `level` | main/sub/building/panel → main or sub |
| `parentMeterId` | `parent_meter_id` | Resolve code → UUID after insert |
| `unit` | `unit` | Map string to enum |
| `conversionFactor` | `meter_multiplier` | CT ratio, pulse factor |
| `sortOrder` | `sort_order` | |
| `isActive` | `is_active` | |
| `isGroupNode` | — | Skip or create as display-only (TBD) |
| `isTankNode` | — | Display-only; omit from readings |
| `omitFromTree` | `include_in_dashboard` | Invert logic |

**Legacy meter inventory (MOEHE HQ):**

*Electricity:*
- LVP-MAIN (group node), LVP-1, LVP-2A, LVP-3A, LVP-4, LVP-5, LVP-6, LVP-7A, LVP-8A

*Water — Kahramaa:*
- 1219053 (main), KP-8530916, KF-18540109, GR-01, GR-02, B1–B5

*Water — Ashghal:*
- 19ACI 005333 (main), K22223190003505907, KF-18540133, 15215002323, STORM-ULTRASONIC

*Tank nodes (display only):*
- TANK-IRR, TANK-MAKEUP, TANK-FIRE

*Virtual:*
- WF (Water Features) — **migrate as virtual meter** with `meter_kind = virtual`, `calculation_type = parent_minus_children`, `parent_meter_id = 1219053`

### 3.3 Readings

| Legacy | Supabase |
|--------|----------|
| Collection: `waterReadings/{YYYY-MM-DD}` | `meter_readings` rows |
| Collection: `electricityReadings/{YYYY-MM-DD}` | `meter_readings` rows |
| Doc fields: `{meterCode: {value, imageUrl}}` | One row per meter per date |
| Cumulative value | `raw_value` |
| — | `normalized_value` (computed by trigger) |
| — | `site_id`, `meter_id` (UUID FK) |
| — | `entered_by` (migration user or null) |

**Migration script logic (future):**
```
for each date doc in Firestore:
  for each meterCode, data in doc.fields:
    meter_id = lookup(meterCode)
    insert meter_readings (site_id, meter_id, reading_date, raw_value, image_url)
```

### 3.4 Images

| Legacy path | New path |
|-------------|----------|
| `meter_images/water/{date}/{meterCode}_{timestamp}.jpg` | `{org_id}/{site_id}/water/{date}/{meter_id}.jpg` |
| `meter_images/electricity/...` | `{org_id}/{site_id}/electricity/{date}/{meter_id}.jpg` |

Download from Firebase Storage → upload to Supabase `meter-images` bucket. Update `meter_readings.image_url`.

### 3.5 Users

Legacy: anonymous auth, no users.  
New: Create real users post-migration; no user data to migrate.

---

## 4. Migration Phases

### Phase A — Schema ready (blocked on approval)
- Execute `001_schema.sql`, `002_rls_policies.sql`, `003_storage.sql`
- Run seed for MOEHE org + site + sample meters
- Create super_admin user

### Phase B — Full meter import
1. Parse canonical `seed_meters.dart` or export SharedPreferences from device
2. Insert all MOEHE HQ meters with code → UUID mapping table
3. Second pass: resolve `parent_meter_id` from codes
4. Validate hierarchy (no cycles, sub → main only)
5. Reconcile admin vs entry seed differences (15215002323 parent)

### Phase C — Readings import
1. Export Firestore `waterReadings` and `electricityReadings` collections
2. Transform to `meter_readings` insert statements
3. Batch insert with conflict handling (`ON CONFLICT DO UPDATE` or skip)
4. Verify reading counts per meter vs legacy

### Phase D — Image import
1. List Firebase Storage objects under `meter_images/`
2. Map to new path convention
3. Upload to Supabase Storage
4. Update `image_url` on corresponding readings

### Phase E — Validation
1. Compare daily consumption for sample dates (legacy calculator vs Supabase view)
2. Verify hierarchy map renders correctly
3. Spot-check images accessible via signed URLs
4. Document any discrepancies

### Phase F — Cutover
1. Freeze new entries in legacy apps (operational decision)
2. Point entry_app and dashboard_app to Supabase
3. Keep legacy Firebase as read-only archive for 90 days

---

## 5. Migration Scripts (to be created later)

```
scripts/
├── export_firestore_readings.js      # Firebase Admin SDK
├── export_firebase_storage.js
├── import_meters.sql                 # Generated from seed_meters.dart
├── import_readings.sql               # Generated from Firestore export
├── migrate_images.ts                 # Firebase → Supabase Storage
└── validate_migration.sql            # Count and spot-check queries
```

**Not created in planning phase.**

---

## 6. Code → UUID Mapping Table

Maintain during migration:

```sql
create table if not exists migration.meter_code_map (
  legacy_meter_code text primary key,
  new_meter_id uuid not null references public.meters(id),
  migrated_at timestamptz default now()
);
```

Drop or archive after validation.

---

## 7. Known Legacy Issues to Resolve

| Issue | Resolution |
|-------|------------|
| Admin seed vs entry seed parent mismatch for `15215002323` | Use water_readings_app seed as canonical |
| Group node `LVP-MAIN` has no readings | Insert as meter with `include_in_dashboard=true` or skip readings |
| Tank nodes have no readings | Insert for map display; exclude from entry |
| Virtual meter `WF` | Create virtual meter row; dashboard computes parent_minus_children |
| kVAh treated as 1:1 kWh | Preserve approximation; document in UI |
| BTU meters not in legacy | Add fresh in Supabase; no migration needed |
| COP not in legacy | Configure fresh via admin_app |

---

## 8. Rollback Plan

- Legacy Firebase stack remains frozen and unchanged
- If Supabase migration fails validation, continue using legacy apps
- No destructive operations on Firebase data
- Supabase data can be truncated and re-imported

---

## 9. Reference Files

| Purpose | Path |
|---------|------|
| Canonical meter seed | `water_readings_app/lib/data/seed/seed_meters.dart` |
| Firestore repository | `water_readings_app/lib/data/repositories/readings_repository.dart` |
| Unit converter | `water_readings_app/lib/domain/meter_unit_converter.dart` |
| Consumption + WF | `water_readings_app/lib/domain/consumption_calculator.dart` |
| App constants | `water_readings_app/lib/core/constants/app_constants.dart` |
| Integration tests | `water_readings_app/README-INTEGRATION-TESTS.md` |
| Legacy status | `meters-legacy-stack/STATUS.md` |

---

## 10. Success Criteria

- [ ] All active legacy meters imported with correct hierarchy
- [ ] 100% of Firestore reading dates migrated (or documented exceptions)
- [ ] Consumption values match legacy calculator within rounding tolerance
- [ ] Images accessible for migrated readings
- [ ] No modifications to legacy Firebase apps or data
- [ ] MOEHE HQ operational on new entry_app and dashboard_app
