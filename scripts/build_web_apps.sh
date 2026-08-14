#!/usr/bin/env bash
# Build Dashboard, Entry, and Admin Flutter web apps for GitHub Pages hosting.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_DIR="${WEB_DEPLOY_DIR:-$ROOT/web_deploy}"

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
APP_ENV="${APP_ENV:-production}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "Set SUPABASE_URL and SUPABASE_ANON_KEY before building web apps." >&2
  exit 1
fi

# GITHUB_* are only set inside Actions; default them so the script also runs
# locally under `set -u`.
REPO_NAME="${GITHUB_REPOSITORY_NAME:-${GITHUB_REPOSITORY:-smart-meters-platform}}"
REPO_NAME="${REPO_NAME##*/}"
REPO_NAME="${REPO_NAME:-smart-meters-platform}"
PAGES_BASE="${GITHUB_PAGES_BASE:-https://${GITHUB_REPOSITORY_OWNER:-example}.github.io}"

# Base path the apps are served under.
#
# On a custom domain the site is the origin root, so the prefix must be empty
# and each app resolves at /dashboard/, /entry/, /admin/. On the project Pages
# URL the site lives under /<repo>/, which is the default kept here so an
# unconfigured build still behaves exactly as before.
#
# Set WEB_BASE_HREF="" (or "/") for a root-served custom domain.
if [[ -n "${WEB_BASE_HREF+x}" ]]; then
  BASE_HREF="${WEB_BASE_HREF%/}"        # tolerate a trailing slash
else
  BASE_HREF="/${REPO_NAME}"
fi

# Written into the published output so GitHub Pages keeps the custom domain.
# peaceiris/actions-gh-pages force-pushes the publish directory, so a CNAME
# created from the repository settings alone would be wiped on the next deploy.
PAGES_CNAME="${PAGES_CNAME:-}"
WEB_DASHBOARD_URL="${WEB_DASHBOARD_URL:-${PAGES_BASE}${BASE_HREF}/dashboard/}"
WEB_ENTRY_URL="${WEB_ENTRY_URL:-${PAGES_BASE}${BASE_HREF}/entry/}"
WEB_ADMIN_URL="${WEB_ADMIN_URL:-${PAGES_BASE}${BASE_HREF}/admin/}"

DART_DEFINES=(
  --dart-define=SUPABASE_URL="$SUPABASE_URL"
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
  --dart-define=APP_ENV="$APP_ENV"
  --dart-define=WEB_DASHBOARD_URL="$WEB_DASHBOARD_URL"
  --dart-define=WEB_ENTRY_URL="$WEB_ENTRY_URL"
  --dart-define=WEB_ADMIN_URL="$WEB_ADMIN_URL"
)

rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

if [[ -n "$PAGES_CNAME" ]]; then
  printf '%s\n' "$PAGES_CNAME" >"$DEPLOY_DIR/CNAME"
  echo "CNAME: $PAGES_CNAME"
fi

build_app() {
  local folder="$1"
  local slug="$2"
  local title="$3"

  echo "=== Building web: $title ==="
  cd "$ROOT/apps/$folder"
  flutter pub get
  flutter build web --release \
    --base-href="${BASE_HREF}/${slug}/" \
    "${DART_DEFINES[@]}"
  mkdir -p "$DEPLOY_DIR/$slug"
  cp -R build/web/. "$DEPLOY_DIR/$slug/"
}

build_app dashboard_app dashboard "Smart Meters Dashboard"
build_app entry_app entry "Smart Meters Entry"
build_app admin_app admin "Smart Meters Admin"

cat >"$DEPLOY_DIR/index.html" <<EOF
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Smart Meters Platform</title>
  <style>
    :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #0f1419; color: #e8edf5; }
    main { width: min(720px, 92vw); padding: 2rem; }
    h1 { margin: 0 0 0.5rem; font-size: 1.75rem; }
    p { opacity: 0.85; line-height: 1.6; }
    .grid { display: grid; gap: 1rem; margin-top: 1.5rem; }
  </style>
</head>
<body>
  <main>
    <h1>منصة العدادات الذكية</h1>
    <p>اختر التطبيق للمتابعة. جميع الصفحات متصلة بـ Supabase staging وتدعم الانتقال بين العرض والإدخال والإدارة.</p>
    <div class="grid">
      <a href="./dashboard/">لوحة العرض (Dashboard)</a>
      <a href="./entry/">إدخال القراءات (Entry)</a>
      <a href="./admin/">الإدارة (Admin)</a>
    </div>
  </main>
</body>
</html>
EOF

echo "Web bundle ready at: $DEPLOY_DIR"
echo "Dashboard: $WEB_DASHBOARD_URL"
echo "Entry:     $WEB_ENTRY_URL"
echo "Admin:     $WEB_ADMIN_URL"
