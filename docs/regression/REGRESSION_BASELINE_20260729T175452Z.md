# Regression Snapshot — BASELINE

- Captured at: `2026-07-29T17:54:57.470912+00:00`
- Git: `feature/conservation-management` @ `74e4449155494991824d7b0eed9f1e36162ce9d0`

| Metric | Count |
|--------|------:|
| organizations | 1 |
| zones | 8 |
| sites | 4 |
| meters | 35 |
| meters_physical | 35 |
| meters_virtual | 0 |
| meter_readings | 43845 |
| reading_photos | 4 |
| profiles | 14 |
| user_site_access | 18 |
| cop_groups | 1 |
| cop_btu_links | 3 |
| cop_elec_links | 3 |
| migration_count | 55 |
| migration_max | 055 |

## Profiles by role
```json
{
  "site_admin": 1,
  "super_admin": 2,
  "technician": 6,
  "technician_request": 1,
  "viewer": 4
}
```

## Profiles by approval
```json
{
  "approved": 12,
  "rejected": 1,
  "suspended": 1
}
```

## Storage buckets
```json
[
  {
    "id": "meter-images",
    "name": "meter-images"
  },
  {
    "id": "profile-avatars",
    "name": "profile-avatars"
  },
  {
    "id": "report-logos",
    "name": "report-logos"
  }
]
```

JSON: `<repo>/docs/regression/snapshot_BASELINE_20260729T175452Z.json`

## Additional baseline notes

- Virtual meters in Staging: **0**
- COP groups: **1** (3 BTU links, 3 electricity links)
- Last reading sample: newest date observed **2026-07-28**; some meters last **2026-05-31**
- `schema_migrations` max version on Staging: **055** (repo files exist through 062 — tracking gap)
- Dashboard smoke (manual): deferred to after test gate; flags N/A
- Restore drill against this baseline: **PASS** (see `docs/STAGING_RESTORE_RUNBOOK.md`)
- Compare script: `scripts/conservation/compare_regression_snapshot.sh`

## Preflight gate

See `docs/regression/PREFLIGHT_GATE_REPORT.md` — **STOP** before P1A due to 2 pre-existing failing tests.
