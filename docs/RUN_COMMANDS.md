# Run Commands

Copy `.env.example` → `.env.local` and fill `SUPABASE_URL` / `SUPABASE_ANON_KEY` from
Supabase Dashboard → Project Settings → API (anon/publishable key only).

Local run scripts source `.env.local` via `scripts/load_env.sh` and pass
`--dart-define=APP_ENV=staging` by default.

---

## macOS (desktop)

```bash
# Requires .env.local or exported SUPABASE_* vars
./scripts/run_dashboard_macos.sh
./scripts/run_admin_macos.sh
./scripts/run_entry_macos.sh
```

Override credentials:

```bash
export SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export SUPABASE_ANON_KEY=<your-anon-key>
export APP_ENV=staging
./scripts/run_dashboard_macos.sh
```

Build without running:

```bash
cd apps/dashboard_app
flutter build macos --debug \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_ENV=staging
```

Output: `apps/dashboard_app/build/macos/Build/Products/Debug/Smart Meters.app` (product name may vary)

---

## Android

```bash
export SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export SUPABASE_ANON_KEY=<anon-key>
export APP_ENV=staging

./scripts/run_staging_app.sh dashboard
./scripts/run_staging_app.sh admin
./scripts/run_staging_app.sh entry

# Or install helpers
./scripts/run_dashboard_android.sh install
```

List devices: `flutter devices`

---

## Analyze & test

```bash
cd packages/smart_meters_core && flutter analyze && flutter test
cd apps/dashboard_app && flutter analyze && flutter test
cd apps/admin_app && flutter analyze && flutter test
cd apps/entry_app && flutter analyze && flutter test
```

---

## MOEHE HQ import (admin CLI)

```bash
export SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export SUPABASE_ANON_KEY=<anon-key>
export IMPORT_ADMIN_EMAIL=<admin-email>
export IMPORT_ADMIN_PASSWORD=<admin-password>

python3 scripts/import_moehe_hq_reports.py --dry-run
python3 scripts/import_moehe_hq_reports.py --apply
```

---

## macOS entitlements

Network client access is required for Supabase HTTPS:

- `apps/*/macos/Runner/DebugProfile.entitlements` — `com.apple.security.network.client = true`
- `apps/*/macos/Runner/Release.entitlements` — same
