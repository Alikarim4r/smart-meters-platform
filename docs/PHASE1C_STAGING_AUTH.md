# Phase 1C — Staging Auth Testing

**Environment:** `smart-meters-platform` staging (`iqcxgtpcfhoapnklxdyl`)  
**Status:** Login + profile load + **approval gate** + role-gated home

---

## Auth accounts for testing

Use **staging validation users only** from `scripts/phase1a_setup_test_users.sql`.

| Email | Role | Approval | Use with app |
|-------|------|----------|--------------|
| `test-super-admin@validation.local` | `super_admin` | approved | admin_app |
| `test-site-admin@validation.local` | `site_admin` | approved | admin_app, entry_app, dashboard_app |
| `test-technician@validation.local` | `technician` | approved | entry_app, dashboard_app |
| `test-viewer@validation.local` | `viewer` | approved | dashboard_app only |

Passwords are defined in `scripts/phase1a_setup_test_users.sql` (staging only — do not use in production).

**Approval fixture users** (from `phase1e_user_approval_validation.sql` on staging):

| Email | Expected screen |
|-------|-----------------|
| `rejected-user@validation.local` | "Your account request was rejected." |
| `suspended-user@validation.local` | "Your account is suspended. Contact admin." |
| `pending-viewer@validation.local` | "Your account request was rejected." (rejected by validation run) |

**Do not use** `alikarim4r@gmail.com` for Phase 1C auth testing. Password recovery redirects to `localhost:3000` until web auth callback and reset-password screens are implemented.

---

## Configure Supabase (anon key only)

1. Supabase Dashboard → **Project Settings** → **API**
2. Copy **Project URL** and **anon public** key
3. Export locally (do not commit):

```bash
export SUPABASE_URL=https://iqcxgtpcfhoapnklxdyl.supabase.co
export SUPABASE_ANON_KEY=<anon-key-from-dashboard>
```

Or copy `.env.example` to `.env.local`, fill values, then `source .env.local`.

**Never** use or commit the `service_role` key in app source.

---

## Run an app

```bash
chmod +x scripts/run_staging_app.sh

./scripts/run_staging_app.sh admin
./scripts/run_staging_app.sh entry
./scripts/run_staging_app.sh dashboard
```

Or manually from an app directory:

```bash
cd apps/entry_app
flutter run \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

---

## Expected behaviour (Phase 1C + approval gate)

1. Login screen appears when no session exists
2. Sign-in loads `profiles` row via RLS (including `approval_status`)
3. **Pending / rejected / suspended** users stay signed in but see a status screen (not the app home)
4. **Approved** users without site assignment see "No sites assigned. Contact admin." (entry/dashboard)
5. Role mismatch shows access-denied (e.g. viewer on entry_app or admin_app)
6. Approved users with correct role and sites reach the app home
7. Sign out returns to login

### Registration (future)

New technician sign-up should send metadata `requested_role: technician_request`. The backend `handle_new_user` trigger sets `approval_status = pending` and `is_active = false`. Full registration UI is not built yet.

---

## Not in Phase 1C

- Password reset / magic link / OAuth
- Reading entry, dashboard charts, admin CRUD
- Storage image upload
- Personal super_admin login

These follow in later phases after feature screens are built.
