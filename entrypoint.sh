#!/bin/sh
set -e

echo "=== Paperclip Railway Entrypoint ==="

# Auto-generate BETTER_AUTH_SECRET if not set
if [ -z "$BETTER_AUTH_SECRET" ]; then
  if [ -f /paperclip/.auth_secret ]; then
    export BETTER_AUTH_SECRET=$(cat /paperclip/.auth_secret)
  else
    export BETTER_AUTH_SECRET=$(head -c 32 /dev/urandom | base64)
    mkdir -p /paperclip
    echo "$BETTER_AUTH_SECRET" > /paperclip/.auth_secret
    chmod 600 /paperclip/.auth_secret
    echo "Generated BETTER_AUTH_SECRET"
  fi
fi

export PORT=${PORT:-3100}

# Auto-detect public URL
if [ -z "$PAPERCLIP_PUBLIC_URL" ] && [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  export PAPERCLIP_PUBLIC_URL="https://$RAILWAY_PUBLIC_DOMAIN"
fi

# Exposure mode
if [ -n "$PAPERCLIP_PUBLIC_URL" ]; then
  export PAPERCLIP_DEPLOYMENT_EXPOSURE=public
  export PAPERCLIP_AUTH_BASE_URL_MODE=explicit
else
  export PAPERCLIP_DEPLOYMENT_EXPOSURE=private
fi

mkdir -p /paperclip
chown -R node:node /paperclip 2>/dev/null || true

BOOTSTRAP_MARKER="/paperclip/.bootstrapped"

echo "Starting Paperclip (mode=$PAPERCLIP_DEPLOYMENT_MODE, exposure=$PAPERCLIP_DEPLOYMENT_EXPOSURE, port=$PORT)"

if [ ! -f "$BOOTSTRAP_MARKER" ]; then
  # First run: start server, wait for DB, bootstrap admin
  gosu node node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js &
  SERVER_PID=$!

  echo "Waiting for database..."
  for i in $(seq 1 60); do
    if gosu node node -e "require('net').connect(54329,'127.0.0.1',()=>process.exit(0)).on('error',()=>process.exit(1))" 2>/dev/null; then
      echo "Database ready after ${i}s"
      break
    fi
    sleep 1
  done

  sleep 5

  # Bootstrap using our script (pg module is already installed in the monorepo)
  echo "Running admin bootstrap..."
  gosu node node /app/bootstrap.mjs 2>&1 || echo "Bootstrap script finished with errors (non-fatal)"

  touch "$BOOTSTRAP_MARKER"
  chown node:node "$BOOTSTRAP_MARKER" 2>/dev/null || true

  wait $SERVER_PID
else
  exec gosu node node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
fi
