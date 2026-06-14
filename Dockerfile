# Paperclip on Railway — with Codex CLI installed at build time

# syntax=docker/dockerfile:1.20
FROM node:lts-trixie-slim AS build

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl git python3 \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable

ARG PAPERCLIP_VERSION=master

WORKDIR /app

RUN git clone --depth 1 --branch ${PAPERCLIP_VERSION} https://github.com/paperclipai/paperclip.git .

RUN pnpm install --frozen-lockfile

RUN pnpm --filter @paperclipai/ui build \
  && pnpm --filter @paperclipai/plugin-sdk build \
  && pnpm --filter @paperclipai/server build \
  && test -f server/dist/index.js


FROM node:lts-trixie-slim AS production

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl gosu openssh-client jq git \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable \
  && curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh \
  && mkdir -p /paperclip /data/.codex \
  && chown -R node:node /paperclip /data

WORKDIR /app

COPY --chown=node:node --from=build /app /app
COPY entrypoint.sh /usr/local/bin/railway-entrypoint.sh
COPY bootstrap.mjs /app/bootstrap.mjs

RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENV NODE_ENV=production \
  HOME=/paperclip \
  CODEX_HOME=/data/.codex \
  HOST=0.0.0.0 \
  PORT=3100 \
  SERVE_UI=true \
  PAPERCLIP_HOME=/paperclip \
  PAPERCLIP_INSTANCE_ID=default \
  PAPERCLIP_DEPLOYMENT_MODE=authenticated \
  PAPERCLIP_DEPLOYMENT_EXPOSURE=private

EXPOSE 3100

CMD ["/usr/local/bin/railway-entrypoint.sh"]
