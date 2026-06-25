# life-ops-agent

An always-on [Claude Code](https://claude.com/claude-code) session running in Docker, controllable from the Claude app (Remote Control).

## Run

```bash
cp .env.example .env                 # set PROJECT_PATH, TZ
docker volume create obsidian-vault  # shared vault volume
docker compose up -d
```

First boot is unauthenticated. Log in once — it persists in the `claude-config` volume:

```bash
docker exec -it claude-remote claude   # run /login, then /exit
docker compose restart
```

The session then shows up in the Claude app / claude.ai/code.

## Config

| Setting | Purpose |
|---|---|
| `PROJECT_PATH` (`.env`) | host dir mounted at `/project` — the session's working directory |
| `TZ` (`.env`) | container timezone |
| `claude-config` volume | persists the login |
| `obsidian-vault` volume | mounted at `/vault` |

The image is built by GitHub Actions and published to GHCR; the compose pulls it (no local build). Only outbound HTTPS is required — no ports are exposed.
