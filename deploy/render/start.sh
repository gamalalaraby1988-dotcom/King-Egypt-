#!/bin/bash
set -u

if [ -z "${PORT:-}" ]; then
    echo "PORT must be provided by the hosting platform." >&2
    exit 1
fi

godot --headless --path /app -- --dedicated-server &
GODOT_PID=$!

ready=0
for _ in $(seq 1 60); do
    if ! kill -0 "$GODOT_PID" 2>/dev/null; then
        wait "$GODOT_PID"
        exit $?
    fi
    if timeout 1 bash -c ':</dev/tcp/127.0.0.1/2456' 2>/dev/null; then
        ready=1
        break
    fi
    sleep 1
done

if [ "$ready" -ne 1 ]; then
    echo "Godot game server did not open its internal WebSocket port." >&2
    kill "$GODOT_PID" 2>/dev/null || true
    wait "$GODOT_PID" 2>/dev/null || true
    exit 1
fi

envsubst '${PORT}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf
nginx -g 'daemon off;' &
NGINX_PID=$!

wait -n "$GODOT_PID" "$NGINX_PID"
STATUS=$?
kill "$GODOT_PID" "$NGINX_PID" 2>/dev/null || true
wait "$GODOT_PID" 2>/dev/null || true
wait "$NGINX_PID" 2>/dev/null || true
exit "$STATUS"
