# Next Steps

**Last updated:** 2026-08-06

---

## Done in-repo (Staging professional build)

- Pre-production hardening on Staging (migrations 115–117, offline isolation, password rotation)
- Conservation Phases 1–6 closed; Phase 7 UX shipped (tabbed IA, Arabic domain labels, number formatting, Source Health empty state)
- Local shade notifications + Android home widgets (no FCM yet)
- CI analyze/test; web portal on `gh-pages`
- Health report: [PROJECT_HEALTH_REPORT_2026-08-05.md](./PROJECT_HEALTH_REPORT_2026-08-05.md)

---

## Waiting on operator (Production cutover)

1. **Decision:** promote a Production Supabase project (new project + full migration chain including 114 order)
2. **GitHub Secrets** — prod `SUPABASE_URL` / `SUPABASE_ANON_KEY` for web deploy
3. **Release keystore** + per-app `android/key.properties` + Play/Apple tracks
4. **Auth policy** — email confirmation vs SSO
5. Optional: disable Review flags / clean Demo data via approved scripts only
6. Optional: FCM if killed-app push is required

See [GRADUAL_LAUNCH.md](./GRADUAL_LAUNCH.md).

---

## Optional product follow-ups

1. iOS home widgets
2. Conservation query fan-out profiling under many flags ON
3. Monitoring (Sentry) + RLS audit automation
4. Windows package refresh on portal if needed

---

*No Production promotion without an explicit operator go-ahead.*
