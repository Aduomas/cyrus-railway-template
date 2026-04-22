# Cyrus on Railway (self-host template)

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/ZTGyIH?referralCode=Pd-ldD&utm_medium=integration&utm_source=template&utm_campaign=generic)

One-click-ish Railway template for self-hosting [Cyrus](https://github.com/cyrusagents/cyrus) — the Claude Code background agent for Linear.

This template runs the `cyrus` CLI as a long-lived service on Railway, with state persisted to a mounted volume. You bring your own Linear OAuth app, Anthropic API key, and GitHub token.

## What this template gives you

- Node 22 container with `git`, `gh`, `jq`, and `cyrus-ai` preinstalled
- State, tokens, and cloned repos persisted at `/data` (Railway volume)
- `$PORT` → `CYRUS_SERVER_PORT` bridging and `CYRUS_BASE_URL` auto-derived from the Railway public domain
- No wrapper service — everything the official CLI does, just in a container

## Deploy

### 1. First deploy (empty)

Click "Deploy on Railway" (or import this repo manually). Attach a **Volume** mounted at `/data`. Enable **Public Networking**.

At this point the container will boot but Cyrus won't do anything useful yet — you still need Linear OAuth credentials.

### 2. Create the Linear OAuth app

Once deployed, copy your Railway public domain (e.g. `cyrus-production-abcd.up.railway.app`). Then:

1. Linear → your workspace → **Settings → API → OAuth Applications → Create new**
2. **Name:** `Cyrus` · **Description:** anything
3. **Callback URL:** `https://<your-railway-domain>/callback`
4. Toggle **Client credentials** ON
5. Toggle **Webhooks** ON
6. **Webhook URL:** `https://<your-railway-domain>/linear-webhook`
7. **App events:** check **Agent session events** (required), **Inbox notifications**, **Permission changes**
8. Save. Copy the **Client ID**, **Client Secret**, and **Webhook Signing Secret** (shown once).

### 3. Set Railway variables

In the Railway service → **Variables**, add:

| Variable | Value |
|---|---|
| `LINEAR_CLIENT_ID` | from step 2 |
| `LINEAR_CLIENT_SECRET` | from step 2 |
| `LINEAR_WEBHOOK_SECRET` | from step 2 |
| `ANTHROPIC_API_KEY` | from [console.anthropic.com](https://console.anthropic.com) |

Optional:

| Variable | Purpose |
|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | Use your Max subscription instead of API key. Generate with `claude setup-token` on a machine that has Claude Code. |
| `CYRUS_BASE_URL` | Only set if you're using a custom domain. Otherwise the entrypoint derives it from `RAILWAY_PUBLIC_DOMAIN`. |

Redeploy the service after adding the variables.

### 4. Finish setup via Railway shell

Install the Railway CLI and connect it to the service:

```bash
brew install railway
railway link
```

Open a shell inside the running container and complete the two interactive steps:

```bash
railway shell

# Inside the container:
cyrus self-auth-linear
# → prints an authorization URL. Open it in your browser,
#   click Authorize. Tokens are written to /data/.cyrus/config.json.

cyrus self-add-repo https://github.com/yourorg/yourrepo.git
# → clones the repo into /data/.cyrus/repos/ and wires it into config.
```

Cyrus watches its config file, so no restart is needed — the main process picks up the new repo.

### 5. Configure `gh` for PR creation (first time only)

In the same shell:

```bash
gh auth login
# choose GitHub.com → HTTPS → paste a PAT with `repo` scope
```

Or, if you prefer, set `GH_TOKEN` as a Railway variable and `gh` will use it automatically.

## How it works

- Railway injects `PORT` at runtime. `entrypoint.sh` exports `CYRUS_SERVER_PORT=$PORT` before `exec cyrus`, so Railway's router points at the right port.
- `HOME` is set to `/data`, which is the volume mount. So `~/.cyrus/` — where Cyrus stores `config.json`, OAuth tokens, and cloned repos — lives on persistent disk.
- `CYRUS_BASE_URL` defaults to `https://$RAILWAY_PUBLIC_DOMAIN`, matching the URL Linear uses to reach your instance.
- The container runs `cyrus` directly under `tini` (PID 1 for proper signal handling).

## Updating Cyrus

The Dockerfile pins `cyrus-ai@latest` by default. To pin a specific version, set the build arg:

```toml
# railway.toml
[build.args]
CYRUS_VERSION = "0.2.48"
```

Or rebuild the service to pull the newest published version.

## Troubleshooting

**Container keeps restarting.** Check Railway logs. Most common causes: missing `ANTHROPIC_API_KEY`, missing Linear env vars, volume not mounted at `/data`.

**Webhooks not arriving.** Confirm the Linear webhook URL is exactly `https://<railway-domain>/linear-webhook` and that `LINEAR_WEBHOOK_SECRET` matches what Linear generated. Check logs for webhook attempts.

**OAuth callback fails.** The callback URL in your Linear app must match `https://<railway-domain>/callback` exactly. If you change the Railway domain (e.g. to a custom one), update both the Linear app and `CYRUS_BASE_URL`.

**"Not authorized"-style errors on issue assignment.** You probably skipped `cyrus self-auth-linear` — the app credentials authenticate Cyrus as an app, but you also need user OAuth to act on behalf of your workspace. Re-run it.

**Lost state after redeploy.** The volume isn't mounted at `/data`, or `HOME` is being overridden. Verify `requiredMountPath = "/data"` in `railway.toml` and that the Railway service shows a volume attached.

## Cost expectations

- Railway: one service + one small volume, typically a few dollars a month at idle.
- Anthropic API: this dominates. A single non-trivial Cyrus issue can run $0.50–$5 in tokens depending on repo size and how much back-and-forth happens. Budget accordingly.

## License

MIT for this template. Cyrus itself is Apache 2.0 — see [cyrusagents/cyrus](https://github.com/cyrusagents/cyrus).
