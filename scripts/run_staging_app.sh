#!/usr/bin/env bash
# Run a Flutter app against staging (or any env) using SUPABASE_* + APP_ENV.
#
# Usage:
#   cp .env.example .env.local   # fill values
#   ./scripts/run_staging_app.sh admin|entry|dashboard [extra flutter run args]

set -euo pipefail

APP="${1:-}"
shift || true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
export APP_ENV="${APP_ENV:-staging}"

case "$APP" in
  admin)    DIR="apps/admin_app" ;;
  entry)    DIR="apps/entry_app" ;;
  dashboard) DIR="apps/dashboard_app" ;;
  *)
    echo "Usage: $0 admin|entry|dashboard [flutter run args...]" >&2
    exit 1
    ;;
esac

cd "$ROOT/$DIR"

flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_ENV="$APP_ENV" \
  "$@"
