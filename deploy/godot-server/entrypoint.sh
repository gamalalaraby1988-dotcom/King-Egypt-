#!/bin/sh
set -eu

STAGING_URL="https://unwrlvyjrtdwobcktetd.supabase.co"

fail() {
  echo "KING CITY staging startup blocked: $1" >&2
  exit 1
}

# Fail closed: this image is for TEST only and must never silently fall back
# to the production URL/key embedded in project.godot.
[ "${KING_CITY_SUPABASE_URL:-}" = "$STAGING_URL" ] || fail "KING_CITY_SUPABASE_URL must be the TEST project URL."
[ -n "${KING_CITY_SUPABASE_PUBLISHABLE_KEY:-}" ] || fail "KING_CITY_SUPABASE_PUBLISHABLE_KEY is required."
[ -n "${KING_CITY_SESSION_SERVER_ID:-}" ] || fail "KING_CITY_SESSION_SERVER_ID is required."
[ -n "${KING_CITY_SESSION_REGION:-}" ] || fail "KING_CITY_SESSION_REGION is required."
[ -n "${KING_CITY_SESSION_ENDPOINT:-}" ] || fail "KING_CITY_SESSION_ENDPOINT is required."
case "$KING_CITY_SESSION_ENDPOINT" in
  wss://*) ;;
  *) fail "KING_CITY_SESSION_ENDPOINT must use wss://." ;;
esac
[ -n "${KING_CITY_SESSION_DIRECTORY_HMAC_SECRET_B64:-}" ] || fail "KING_CITY_SESSION_DIRECTORY_HMAC_SECRET_B64 is required."
if [ "${KING_CITY_TRUSTED_PROXY_MODE:-0}" = "1" ]; then
  [ "$KING_CITY_SUPABASE_URL" = "$STAGING_URL" ] || fail "Trusted proxy mode is restricted to the TEST project."
  echo "KING CITY TEST backend will accept plain WebSocket only behind its private TLS proxy."
else
  [ -n "${KING_CITY_TLS_KEY_PATH:-}" ] || fail "KING_CITY_TLS_KEY_PATH is required."
  [ -n "${KING_CITY_TLS_CERT_PATH:-}" ] || fail "KING_CITY_TLS_CERT_PATH is required."
  [ -r "$KING_CITY_TLS_KEY_PATH" ] || fail "TLS private key is not readable at KING_CITY_TLS_KEY_PATH."
  [ -r "$KING_CITY_TLS_CERT_PATH" ] || fail "TLS certificate is not readable at KING_CITY_TLS_CERT_PATH."
fi

case "${KING_CITY_GAME_PORT:-2456}" in
  *[!0-9]*|'') fail "KING_CITY_GAME_PORT must be a numeric TCP port." ;;
esac

echo "Starting KING OF EGYPT CITY dedicated server in TEST mode on TCP port ${KING_CITY_GAME_PORT:-2456}."
exec /usr/local/bin/godot --headless --path /app -- --dedicated-server
