# Utility Network Model — Phase A (approved decisions)

**Scope:** Backend only (schema, RLS, RPCs, SQL tests). No Flutter. No Production apply from this workstream.  
**031:** Deprecated, retained. Import idempotent into v2. **No dual-write. No delete.**

## Locked decisions (v1)

1. Campus site is the single member for the first network (e.g. MOEHE HQ resolved at runtime — **no hard-coded site/building IDs in migrations**).
2. Buildings are physical areas via `site_facility_areas`, not separate `sites`.
3. `site_facility_areas.area_type`: `campus | building | floor | zone | plant_room | outdoor | common`.
4. `site_utility_network_members` supports 1..N sites later; first network has one member.
5. **Edit:** `super_admin` OR `can_manage_site_meters` for **every** member site.
6. **Full snapshot read:** access to **every** member site (no one-member leak of a multi-site network).
7. Model: networks, members, revisions, assets, ports, revision nodes, connections, views, view nodes.
8. One active Draft + `lock_version`; atomic publish → immutable published + new draft.
9. 031 → import only; stop app writes to 031 after cutover (Phase B+); keep tables.
10–15. Meter editor backend: list/attach existing + atomic create with optional links (below).

## Entity relationship

```text
site_facility_areas (tree per site_id)
sites ── site_utility_network_members ── site_utility_networks
                                            ├── draft_revision_id
                                            ├── published_revision_id
                                            ├── site_utility_network_views
                                            └── site_utility_network_revisions
                                                   ├── revision_nodes → assets → ports
                                                   ├── revision_connections (port→port)
                                                   └── view_nodes (layout)
meters / site_tanks ←── assets.ref_*
```

## Migrations

| File | Purpose |
|------|---------|
| `032_site_facility_areas.sql` | Physical area tree |
| `033_site_utility_network_v2_schema.sql` | Core v2 schema + immutability |
| `034_site_utility_network_v2_rls.sql` | ACL helpers + RLS |
| `035_site_utility_network_v2_rpcs_core.sql` | Create/connect/snapshot |
| `036_…_validate_publish_import.sql` | Validate, publish, import 031, reconcile |
| `037_…_cascade_delete.sql` | Cascade delete when network removed |
| `038_utility_network_meter_picker_rpcs.sql` | Meter picker + attach + atomic create |
| `039_utility_network_phase_a_closure.sql` | Lock no-op, parent replace, single synced parent |

## RLS

| Action | Rule |
|--------|------|
| Edit | `can_manage_utility_network` |
| Full snapshot | `can_read_utility_network_snapshot` (all members) |
| Draft | managers only |
| Published rows | immutable (except cascade after network delete) |

## RPCs (authenticated)

### Core
| RPC | Role |
|-----|------|
| `create_utility_network` | Network + members + draft + default view |
| `ensure_network_draft` | Ensure active draft |
| `create_asset_with_ports` / `create_meter_asset` / `create_tank_asset` | Asset factories |
| `add_asset_to_revision` | Place existing asset on draft |
| `connect_ports` / `disconnect_ports` | Links (+ optional legacy sync) |
| `batch_update_view_positions` | Canvas layout |
| `validate_network_draft` / `publish_network_draft` | Validate + atomic publish |
| `get_network_snapshot` | Draft (manage) or published (full-member read) |
| `import_legacy_network_dry_run` / `_apply` / `reconcile_legacy_network` | 031 bridge |

### Meter picker / editor (Phase A backend for future Flutter)
| RPC | Behavior |
|-----|----------|
| `list_available_meters_for_network(network_id, revision_id?, view_id?, site_id?, search?, limit?)` | Meters on **member sites** only. `availability_status`: `not_in_network` \| `in_network_not_in_current_view` \| `in_current_view` |
| `attach_existing_meter_to_draft(...)` | Reuses `meters` row; upserts **one** asset + revision node + view placement; optional upstream/downstream links. **No duplicate** asset/node on re-attach. |
| `create_meter_in_network_draft(...)` | **Atomic:** new meter + asset + inlet/outlet + revision node + view + optional upstream + **many** downstream links + `parent_meter_id` sync when `legacy_sync_status` allows. Failure rolls back entire call. |

Future Flutter can call these for: existing meter dropdown, new meter form, parent picker, multi-child feeds, and later drag-link via `connect_ports`.

## Tests (staging)

```bash
npx supabase db query --linked -f scripts/sql/test_utility_network_phase_a.sql
npx supabase db query --linked -f scripts/sql/test_utility_network_meter_picker.sql
```

| Suite | Result |
|-------|--------|
| `util_net_test.run_all` | `passed_checks: 29`, `error: null` |
| `util_net_test.run_meter_picker` | `passed_checks: 9`, rollback verified |

Meter picker coverage: list statuses, attach without new `meters` row, no duplicate asset/node, sequential parent sync, parallel downstream, full rollback on bad link.

## Import 031 (staging sample)

Legacy nodes/edges remain; apply is idempotent (`assets_added: 0` on second run). Overflow edges map to overflow ports (not outlet).

## Out of scope here

Flutter Network UI, Dashboard cutover, seeding real building names/IDs, deleting 031, Production migration apply, reading/report changes.
