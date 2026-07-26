# Apply meter hierarchy + tanks + force delete

Super Admin three-level meters, site tanks, and unrestricted delete require these migrations on the database.

Apply in order in the Supabase SQL Editor (staging, then prod).

## Step 1 — `sub_sub` enum

```sql
alter type public.meter_level add value if not exists 'sub_sub';
```

## Step 2 — three-level parent rules

Paste the full contents of  
`supabase/migrations/013_meter_hierarchy_three_levels.sql`

## Step 3 — site tanks + meter destination

Paste the full contents of  
`supabase/migrations/014_site_tanks.sql`

## Step 4 — force-delete RPCs + site_admin site delete

Paste the full contents of  
`supabase/migrations/015_admin_force_delete.sql`

## Verify

```sql
select enumlabel from pg_enum e
join pg_type t on t.oid = e.enumtypid
where t.typname = 'meter_level'
order by enumsortorder;
-- expect: main, sub, sub_sub

select to_regclass('public.site_tanks');
-- expect: site_tanks

select proname from pg_proc
where proname in ('admin_force_delete_meter', 'admin_force_delete_site');
```

## App behaviour after apply

| Role | Delete meters / sites |
|------|------------------------|
| `super_admin` | Force-delete (cascade readings/links) with confirmation |
| `site_admin` | Restricted delete; fails with warning if dependents exist |

Meter form: main/sub can mark **pours into tank**; pick existing tank or type a new name. Sub meters can pick a parent main or **create a new main** inline.
