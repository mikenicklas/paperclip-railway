#!/bin/sh
set -e

echo "=== Paperclip Railway Entrypoint ==="

# Auto-generate BETTER_AUTH_SECRET if not set
if [ -z "$BETTER_AUTH_SECRET" ]; then
  if [ -f /paperclip/.auth_secret ]; then
    export BETTER_AUTH_SECRET=$(cat /paperclip/.auth_secret)
    echo "Loaded BETTER_AUTH_SECRET from /paperclip/.auth_secret"
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
echo "PORT=$PORT"

# Auto-detect public URL from RAILWAY_PUBLIC_DOMAIN if available
if [ -z "$PAPERCLIP_PUBLIC_URL" ] && [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  export PAPERCLIP_PUBLIC_URL="https://$RAILWAY_PUBLIC_DOMAIN"
  echo "Auto-detected PAPERCLIP_PUBLIC_URL=$PAPERCLIP_PUBLIC_URL"
fi

# Exposure mode: upgrade to public only when a public URL is available
if [ -n "$PAPERCLIP_PUBLIC_URL" ]; then
  export PAPERCLIP_DEPLOYMENT_EXPOSURE=public
  export PAPERCLIP_AUTH_BASE_URL_MODE=explicit
  echo "Using public exposure (explicit base URL)"
else
  export PAPERCLIP_DEPLOYMENT_EXPOSURE=private
  echo "Using private exposure (auto base URL)"
fi

# Ensure data directory exists
mkdir -p /paperclip
chown -R node:node /paperclip 2>/dev/null || true

echo "Starting Paperclip (mode=$PAPERCLIP_DEPLOYMENT_MODE, exposure=$PAPERCLIP_DEPLOYMENT_EXPOSURE, port=$PORT)"

# Run as node user via gosu
exec gosu node node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
