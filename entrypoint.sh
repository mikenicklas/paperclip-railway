#!/bin/sh
set -e

# Auto-generate BETTER_AUTH_SECRET if not set
if [ -z "$BETTER_AUTH_SECRET" ]; then
  if [ -f /paperclip/.auth_secret ]; then
    export BETTER_AUTH_SECRET=$(cat /paperclip/.auth_secret)
  else
    export BETTER_AUTH_SECRET=$(head -c 32 /dev/urandom | base64)
    echo "$BETTER_AUTH_SECRET" > /paperclip/.auth_secret
    chmod 600 /paperclip/.auth_secret
    echo "Generated BETTER_AUTH_SECRET (stored in /paperclip/.auth_secret)"
  fi
fi

# Railway sets PORT dynamically
export PORT=${PORT:-3100}

# Auto-detect public URL from RAILWAY_PUBLIC_DOMAIN if available
if [ -z "$PAPERCLIP_PUBLIC_URL" ] && [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  export PAPERCLIP_PUBLIC_URL="https://$RAILWAY_PUBLIC_DOMAIN"
  echo "Auto-detected PAPERCLIP_PUBLIC_URL=$PAPERCLIP_PUBLIC_URL"
fi

# Ensure data directory exists and is owned by node
mkdir -p /paperclip
chown -R node:node /paperclip 2>/dev/null || true

echo "Starting Paperclip (mode=$PAPERCLIP_DEPLOYMENT_MODE, exposure=$PAPERCLIP_DEPLOYMENT_EXPOSURE)"

exec gosu node node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
