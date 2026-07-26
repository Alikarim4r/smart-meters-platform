#!/usr/bin/env bash
# Run dashboard_app on macOS (requires SUPABASE_* env or .env.local).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
cd "$ROOT/apps/dashboard_app"

export SMART_METERS_ROOT="$ROOT"

# Avoid duplicate Smart Meters instances (e.g. open + flutter run).
pkill -f "Smart Meters.app/Contents/MacOS" 2>/dev/null || true
sleep 0.4

flutter run -d macos \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_ENV="$APP_ENV" \
  "$@"
