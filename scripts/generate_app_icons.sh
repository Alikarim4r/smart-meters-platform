#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/scripts/.icon-venv"

if [[ ! -x "$VENV/bin/python3" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install pillow --quiet
fi

"$VENV/bin/python3" "$ROOT/scripts/generate_app_icons.py"

for app in dashboard_app entry_app admin_app; do
  (
    cd "$ROOT/apps/$app"
    flutter pub get
    dart run flutter_launcher_icons
  )
  # Keep Android 12+ / legacy splash in sync with launcher icon when present.
  icon="$ROOT/apps/$app/assets/branding/app_icon_simple.png"
  splash="$ROOT/apps/$app/android/app/src/main/res/drawable-nodpi/splash_logo.png"
  if [[ -f "$icon" && -f "$splash" ]]; then
    cp "$icon" "$splash"
  fi
done

echo "App icons generated for dashboard, entry, and admin."
