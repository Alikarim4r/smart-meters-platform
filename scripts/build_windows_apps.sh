#!/usr/bin/env bash
# Build Windows release bundles for dashboard / entry / admin.
# Must run on Windows (or CI windows-latest). macOS/Linux cannot cross-compile.
#
# Usage (from repo root, PowerShell or Git Bash on Windows):
#   export SUPABASE_URL=... SUPABASE_ANON_KEY=... APP_ENV=staging
#   ./scripts/build_windows_apps.sh
#
# Output:
#   dist/windows/Meter-Dashboard-Windows.zip
#   dist/windows/Meter-Entry-Windows.zip
#   dist/windows/Meter-Admin-Windows.zip

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
export APP_ENV="${APP_ENV:-staging}"

if [[ "$(uname -s 2>/dev/null || echo Windows)" != MINGW* && "$(uname -s 2>/dev/null || true)" != MSYS* && "${OS:-}" != "Windows_NT" ]]; then
  if ! flutter config 2>/dev/null | grep -qi 'enable-windows-desktop: true' && [[ "$(uname -s)" == Darwin || "$(uname -s)" == Linux ]]; then
    echo "ERROR: Flutter Windows builds require a Windows machine (or GitHub Actions windows-latest)." >&2
    echo "Trigger: gh workflow run build-windows.yml -f app_env=$APP_ENV" >&2
    exit 1
  fi
fi

OUT="$ROOT/dist/windows"
mkdir -p "$OUT"

build_one() {
  local app="$1" dir="$2" exe="$3" zip_name="$4"
  echo "==> Building $app (Windows release, APP_ENV=$APP_ENV)"
  cd "$ROOT/$dir"
  flutter pub get
  flutter build windows --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=APP_ENV="$APP_ENV"
  local src="$ROOT/$dir/build/windows/x64/runner/Release"
  if [[ ! -f "$src/$exe" ]]; then
    echo "Missing $src/$exe" >&2
    exit 1
  fi
  rm -f "$OUT/${zip_name}.zip"
  (
    cd "$src"
    if command -v zip >/dev/null 2>&1; then
      zip -r "$OUT/${zip_name}.zip" .
    else
      powershell.exe -NoProfile -Command "Compress-Archive -Path * -DestinationPath '$OUT/${zip_name}.zip' -Force"
    fi
  )
  echo "Wrote $OUT/${zip_name}.zip"
}

build_one dashboard apps/dashboard_app dashboard_app.exe Meter-Dashboard-Windows
build_one entry apps/entry_app entry_app.exe Meter-Entry-Windows
build_one admin apps/admin_app admin_app.exe Meter-Admin-Windows

echo "Done. Zips in $OUT"
