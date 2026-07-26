# Next Steps

**Last updated:** 2026-07-11

---

## Done locally (no user credentials required)

- Staging closeout on limited MOEHE data — [STAGING_CLOSEOUT.md](STAGING_CLOSEOUT.md)
- App env cleanup: `APP_ENV`, no staging login hints in production, no baked Supabase keys in run scripts
- Chart fetch: monthly/yearly use per-bucket latest readings (not full daily pull)
- CI: `.github/workflows/ci.yml` (analyze + test)
- Android signing pattern: `key.properties.example` + gradle loads keystore when present
- Launch plan: [GRADUAL_LAUNCH.md](GRADUAL_LAUNCH.md)

---

## Waiting on you

1. **Production Supabase** — new project + apply migrations `001`–`011` (needs access token or Dashboard)
2. **GitHub Secrets** — prod `SUPABASE_URL` / `SUPABASE_ANON_KEY` for web deploy
3. **Apply `011` indexes** on staging SQL Editor if not applied
4. **Release keystore** + per-app `android/key.properties`
5. **Play / Apple** accounts for store tracks
6. **Auth hardening** — email confirmation / SSO decision

---

## Optional product follow-ups

1. Custom date range picker polish
2. Reduce import metadata churn (`meters_updated`)
3. iOS builds if required
4. Monitoring (Sentry) + RLS audit automation

---

## UX / design (later)

1. Network topology screen
2. Dark mode tokens
3. Arabic RTL polish on exports
4. Wider macOS multi-column charts

---

## Deferred

- Complex custom reports / BI
- Hourly consumption charts
- Service role in client apps (never)
- Legacy Firebase app changes (never)
