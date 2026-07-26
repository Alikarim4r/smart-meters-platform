#!/usr/bin/env bash
# Source gitignored .env.local if present, then require Supabase dart-defines.
# Usage: source "$(dirname "$0")/load_env.sh"
#
# Expected vars: SUPABASE_URL, SUPABASE_ANON_KEY
# Optional: APP_ENV (defaults to staging for local run scripts)

_SMART_METERS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SMART_METERS_ROOT="$(cd "$_SMART_METERS_SCRIPT_DIR/.." && pwd)"

if [[ -f "$_SMART_METERS_ROOT/.env.local" ]]; then
  # shellcheck disable=SC1091
  set -a
  # shellcheck disable=SC1091
  source "$_SMART_METERS_ROOT/.env.local"
  set +a
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Set SUPABASE_URL and SUPABASE_ANON_KEY (export or copy .env.example → .env.local)." >&2
  exit 1
fi

export APP_ENV="${APP_ENV:-staging}"
