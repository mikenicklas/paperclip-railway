# Paperclip on Railway

One-click deployment of [Paperclip](https://github.com/paperclipai/paperclip) — the open-source orchestration control plane for AI agent companies.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/WWilson1017/paperclip-railway)

## What is Paperclip?

Paperclip manages your AI agents like a real company: org charts, task assignments, budgets, and governance. Pair it with [Chatty](https://github.com/WWilson1017/chatty) to run a full AI agent workforce.

## Deploy in 3 Steps

### 1. Click "Deploy on Railway"

Click the button above. Railway will build and deploy Paperclip automatically.

### 2. Add PostgreSQL

After deployment, click **"+ New"** in your Railway project and select **"Database" → "PostgreSQL"**. Railway will provision a managed Postgres instance and set the `DATABASE_URL` variable automatically.

### 3. Set Your Public URL

Once deployed, Railway gives you a public URL (e.g., `paperclip-abc.up.railway.app`). Add it as an environment variable:

```
PAPERCLIP_PUBLIC_URL=https://your-paperclip-url.up.railway.app
```

That's it. Open your Railway URL to create an account and start building your AI company.

## Connect to Chatty

If you're running [Chatty](https://github.com/WWilson1017/chatty) on Railway:

1. Open Chatty → **Settings** → **Integrations** → **Paperclip**
2. Enter your Paperclip Railway URL and Company ID
3. Map your Chatty agents to Paperclip agents
4. Your agents now participate in Paperclip's orchestration

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | — | PostgreSQL connection string (auto-set when you add Railway Postgres) |
| `PAPERCLIP_PUBLIC_URL` | Yes | — | Your Railway public URL (e.g., `https://paperclip-abc.up.railway.app`) |
| `BETTER_AUTH_SECRET` | No | Auto-generated | Auth signing secret. Auto-generated on first boot if not set. |
| `PORT` | No | Railway-assigned | Server port (Railway sets this automatically) |

## Updating

To pull the latest Paperclip release, trigger a redeploy from your Railway dashboard. The Dockerfile clones the latest `main` branch on each build.

To pin to a specific version, set the `PAPERCLIP_VERSION` build argument to a tag or commit hash.
