#!/usr/bin/env bash
set -euo pipefail

# Cyrus hardcodes its server to bind on 127.0.0.1 (SharedApplicationServer.ts
# constructs with host="localhost" and Application.ts never overrides it).
# That's fine on a laptop, unreachable from outside a container.
#
# Workaround: keep Cyrus on 127.0.0.1:3456 and run socat as a thin TCP relay
# from 0.0.0.0:$PORT -> 127.0.0.1:3456. socat handles WebSockets transparently
# since it's a raw TCP forward.

CYRUS_INTERNAL_PORT=3456
export CYRUS_SERVER_PORT="${CYRUS_INTERNAL_PORT}"

# Where external traffic arrives. Railway injects PORT; for local docker runs
# default to 3457 so we don't collide with Cyrus's own port.
LISTEN_PORT="${PORT:-3457}"

if [[ "${LISTEN_PORT}" == "${CYRUS_INTERNAL_PORT}" ]]; then
  echo "ERROR: PORT (${LISTEN_PORT}) must differ from Cyrus's internal port (${CYRUS_INTERNAL_PORT})" >&2
  exit 1
fi

# Auto-derive CYRUS_BASE_URL from Railway's public domain if the user didn't set one.
if [[ -z "${CYRUS_BASE_URL:-}" && -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]]; then
  export CYRUS_BASE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

mkdir -p "${HOME}/.cyrus"

socat -d TCP4-LISTEN:"${LISTEN_PORT}",bind=0.0.0.0,fork,reuseaddr \
      TCP4:127.0.0.1:"${CYRUS_INTERNAL_PORT}" &

exec "$@"
