# Gradual launch

**Strategy:** Web first (all three apps), then Android internal, then store release.

---

## Phase 1 — Web (now)

1. Set GitHub Actions secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (production when ready; staging OK for dry-run).
2. Push to `main` / `master` or run **Deploy Web Apps** workflow.
3. Open GitHub Pages:
   - `/dashboard/`
   - `/entry/`
   - `/admin/`
4. Builds use `APP_ENV=production` (no staging login hints).

Local web build:

```bash
export SUPABASE_URL=... SUPABASE_ANON_KEY=... APP_ENV=production
./scripts/build_web_apps.sh
```

---

## Phase 2 — Android internal

1. Create release keystore (you keep the secrets).
2. Copy [`key.properties.example`](../key.properties.example) → `apps/<app>/android/key.properties`.
3. Build:

```bash
export SUPABASE_URL=... SUPABASE_ANON_KEY=... APP_ENV=production
cd apps/dashboard_app && flutter build appbundle --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_ENV=production
```

4. Distribute via Play internal testing (or sideload debug APK for pilot).

---

## Phase 3 — Stores / macOS (later)

- Play Console listing + production track  
- Apple Developer + iOS if required  
- macOS notarized builds if desktop is in scope  

---

## Waiting on you

| Item | Needed for |
|------|------------|
| Production Supabase project + migrations `001`–`011` | Real prod data plane |
| GitHub Secrets pointing at **prod** URL/key | Phase 1 prod web |
| Keystore + `key.properties` | Phase 2 signed AAB |
| Play / Apple accounts | Phase 3 |
| Auth email confirmation / SSO policy | Hardening |
| Apply `011` indexes on staging SQL Editor if not done | Chart SLA on staging |

---

## Related

- [STAGING_CLOSEOUT.md](STAGING_CLOSEOUT.md) — staging lock-down  
- [RUN_COMMANDS.md](RUN_COMMANDS.md) — local run with `.env.local`  
- CI: `.github/workflows/ci.yml` (analyze + test on PR)
