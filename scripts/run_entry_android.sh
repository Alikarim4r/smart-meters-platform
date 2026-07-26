#!/usr/bin/env bash
# Build and install entry_app on a connected Android device.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/load_env.sh"
cd "$ROOT/apps/entry_app"

DART_DEFINES=(
  --dart-define=SUPABASE_URL="$SUPABASE_URL"
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
  --dart-define=APP_ENV="$APP_ENV"
)

MODE="${1:-install}"
shift || true

case "$MODE" in
  install)
    flutter build apk --debug "${DART_DEFINES[@]}"
    DEVICE="${ANDROID_SERIAL:-}"
    if [[ -z "$DEVICE" ]]; then
      DEVICE="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
    fi
    if [[ -z "$DEVICE" ]]; then
      echo "No Android device found. Connect a device or set ANDROID_SERIAL." >&2
      exit 1
    fi
    adb -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk
    ;;
  build)
    flutter build apk --debug "${DART_DEFINES[@]}"
    ;;
  run)
    flutter run "${DART_DEFINES[@]}" "$@"
    ;;
  *)
    echo "Usage: $0 [install|build|run]" >&2
    exit 1
    ;;
esac
