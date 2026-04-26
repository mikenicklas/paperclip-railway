#!/bin/sh
set -e

echo "=== Paperclip Railway Entrypoint ==="

# Auto-generate BETTER_AUTH_SECRET if not set
if [ -z "$BETTER_AUTH_SECRET" ]; then
  if [ -f /paperclip/.auth_secret ]; then
    export BETTER_AUTH_SECRET=$(cat /paperclip/.auth_secret)
    echo "Loaded BETTER_AUTH_SECRET from file"
  else
    export BETTER_AUTH_SECRET=$(head -c 32 /dev/urandom | base64)
    mkdir -p /paperclip
    echo "$BETTER_AUTH_SECRET" > /paperclip/.auth_secret
    chmod 600 /paperclip/.auth_secret
    echo "Generated BETTER_AUTH_SECRET"
  fi
fi

# Railway sets PORT dynamically
export PORT=${PORT:-3100}

# Auto-detect public URL
if [ -z "$PAPERCLIP_PUBLIC_URL" ] && [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  export PAPERCLIP_PUBLIC_URL="https://$RAILWAY_PUBLIC_DOMAIN"
  echo "Auto-detected PAPERCLIP_PUBLIC_URL=$PAPERCLIP_PUBLIC_URL"
fi

# Exposure mode
if [ -n "$PAPERCLIP_PUBLIC_URL" ]; then
  export PAPERCLIP_DEPLOYMENT_EXPOSURE=public
  export PAPERCLIP_AUTH_BASE_URL_MODE=explicit
  echo "Using public exposure"
else
  export PAPERCLIP_DEPLOYMENT_EXPOSURE=private
  echo "Using private exposure"
fi

# Ensure data directory
mkdir -p /paperclip
chown -R node:node /paperclip 2>/dev/null || true

BOOTSTRAP_MARKER="/paperclip/.bootstrapped"
NEED_BOOTSTRAP=false
if [ ! -f "$BOOTSTRAP_MARKER" ]; then
  NEED_BOOTSTRAP=true
fi

echo "Starting Paperclip (mode=$PAPERCLIP_DEPLOYMENT_MODE, exposure=$PAPERCLIP_DEPLOYMENT_EXPOSURE, port=$PORT)"

if [ "$NEED_BOOTSTRAP" = "true" ]; then
  # First run: start server in background, wait for DB, bootstrap admin, then wait
  gosu node node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js &
  SERVER_PID=$!

  # Wait for embedded Postgres to be ready (up to 60s)
  echo "Waiting for embedded Postgres..."
  for i in $(seq 1 60); do
    if gosu node node -e "const net = require('net'); const s = net.connect(54329, '127.0.0.1', () => { s.end(); process.exit(0); }); s.on('error', () => process.exit(1));" 2>/dev/null; then
      echo "Embedded Postgres ready after ${i}s"
      break
    fi
    sleep 1
  done

  # Small extra wait for migrations to complete
  sleep 3

  # Bootstrap the first admin invite
  BASE_URL="${PAPERCLIP_PUBLIC_URL:-http://localhost:$PORT}"
  DB_URL="postgres://paperclip:paperclip@127.0.0.1:54329/paperclip"

  echo ""
  echo "============================================"
  echo "  BOOTSTRAPPING FIRST ADMIN USER"
  echo "============================================"
  gosu node npx --yes paperclipai auth bootstrap-ceo --db-url "$DB_URL" --base-url "$BASE_URL" 2>&1 || true
  echo "============================================"
  echo ""

  # Mark as bootstrapped
  touch "$BOOTSTRAP_MARKER"
  chown node:node "$BOOTSTRAP_MARKER" 2>/dev/null || true

  # Wait for server process
  wait $SERVER_PID
else
  # Normal startup
  exec gosu node node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
fi
