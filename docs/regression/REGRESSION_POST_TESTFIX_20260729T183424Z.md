# Regression Snapshot — POST_TESTFIX

- Captured at: `2026-07-29T18:34:49.398752+00:00`
- Git: `feature/conservation-management` @ `cf9f5c22751ff9b54719385d94e25fe6b6c104d0`

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

JSON: `<repo>/docs/regression/snapshot_POST_TESTFIX_20260729T183424Z.json`
