# Paperclip on Railway — one-click deployment
# Clones and builds the latest Paperclip from GitHub.

# syntax=docker/dockerfile:1.20
FROM node:lts-trixie-slim AS build
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl git python3 \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable

ARG PAPERCLIP_VERSION=main
WORKDIR /app
RUN git clone --depth 1 --branch ${PAPERCLIP_VERSION} https://github.com/paperclipai/paperclip.git .
RUN pnpm install --frozen-lockfile
RUN pnpm --filter @paperclipai/ui build \
  && pnpm --filter @paperclipai/plugin-sdk build \
  && pnpm --filter @paperclipai/server build \
  && test -f server/dist/index.js

FROM node:lts-trixie-slim AS production
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates gosu openssh-client jq git \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable \
  && mkdir -p /paperclip \
  && chown node:node /paperclip

WORKDIR /app
COPY --chown=node:node --from=build /app /app
COPY entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENV NODE_ENV=production \
  HOME=/paperclip \
  HOST=0.0.0.0 \
  PORT=3100 \
  SERVE_UI=true \
  PAPERCLIP_HOME=/paperclip \
  PAPERCLIP_INSTANCE_ID=default \
  PAPERCLIP_DEPLOYMENT_MODE=authenticated \
  PAPERCLIP_DEPLOYMENT_EXPOSURE=public

EXPOSE 3100

CMD ["/usr/local/bin/railway-entrypoint.sh"]
