#!/usr/bin/env bash
# Build the three Smart Meters zero-state Android App Bundles.
# This script is deliberately fail-closed: it never sources .env.local and it
# refuses staging/Daily Checklists backends or missing production signing keys.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ZERO_STATE_ENV_FILE:-$ROOT/.env.production.local}"
VERSION_NAME="1.0.0"
VERSION_CODE="11"
SMART_METERS_STAGING_REF="iqcxgtpcfhoapnklxdyl"
DAILY_CHECKLISTS_REF="xhdpyiklhouqwrtdwztn"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing production environment file: $ENV_FILE" >&2
  echo "Copy .env.production.example to .env.production.local and fill it from the dedicated Smart Meters Production project." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "SUPABASE_URL and SUPABASE_ANON_KEY are required." >&2
  exit 1
fi
if [[ "${APP_ENV:-}" != "production" ]]; then
  echo "APP_ENV must be exactly production for a zero-state release." >&2
  exit 1
fi
if [[ "$SUPABASE_URL" == *"$SMART_METERS_STAGING_REF"* ]]; then
  echo "Refusing zero-state release: SUPABASE_URL points to Smart Meters staging." >&2
  exit 1
fi
if [[ "$SUPABASE_URL" == *"$DAILY_CHECKLISTS_REF"* ]]; then
  echo "Refusing zero-state release: SUPABASE_URL points to Daily Checklists." >&2
  exit 1
fi
if [[ "$SUPABASE_URL" == *"YOUR_PRODUCTION_PROJECT"* ]]; then
  echo "Refusing placeholder Production URL." >&2
  exit 1
fi

python3 "$ROOT/scripts/check_zero_state_release.py"

APPS=(entry_app admin_app dashboard_app)
for app in "${APPS[@]}"; do
  key_properties="$ROOT/apps/$app/android/key.properties"
  if [[ ! -f "$key_properties" ]]; then
    echo "Missing release signing file: $key_properties" >&2
    exit 1
  fi
done

OUT="$ROOT/dist/zero-state/android"
rm -rf "$OUT"
mkdir -p "$OUT"

for app in "${APPS[@]}"; do
  echo "=== Building $app $VERSION_NAME+$VERSION_CODE ==="
  pushd "$ROOT/apps/$app" >/dev/null
  flutter pub get
  flutter build appbundle --release \
    --build-name="$VERSION_NAME" \
    --build-number="$VERSION_CODE" \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=APP_ENV=production
  src="build/app/outputs/bundle/release/app-release.aab"
  dst="$OUT/$app-$VERSION_NAME+$VERSION_CODE.aab"
  cp "$src" "$dst"
  shasum -a 256 "$dst"
  popd >/dev/null
done

echo "ZERO_STATE_ANDROID_BUILD=PASS"
echo "Artifacts: $OUT"
