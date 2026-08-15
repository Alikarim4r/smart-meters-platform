# Regression Snapshot — POST_P1A

- Captured at: `2026-07-29T19:35:40.847665+00:00`
- Git: `feature/conservation-management` @ `9610b8fdfa9dc93d9c57d350d4c63386d46129a3`

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
| migration_count | 56 |
| migration_max | 063 |

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

JSON: `<repo>/docs/regression/snapshot_POST_P1A_20260729T193535Z.json`
