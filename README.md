# claude-remote — always-on Claude Code on the Beelink

Phase 1: a single, interactively-authenticated `claude --remote-control`
session running in Docker, controllable from the Claude app on your phone.
Because the session is interactive, your existing **claude.ai Gmail / Calendar
connectors work in it directly** — nothing extra to set up to read email or
edit the vault from your phone.

Later phases (not built yet): a cron scheduler for autonomous triage, and
event-based vault updates. See "Roadmap" below.

## What's here

| File | Role |
|------|------|
| `Dockerfile` | node:22-slim + Claude Code CLI, runs as the `node` user under tini |
| `entrypoint.sh` | Idles with login instructions until authenticated, then supervises the remote-control session |
| `compose.yml` | The service: persistent auth volume + project + vault mounts |
| `.env.example` | The two host paths to set on the Beelink |

## First-run, on the Beelink

```bash
cd <this dir on the beelink>
cp .env.example .env
$EDITOR .env                 # set PROJECT_PATH

docker volume create obsidian-vault   # shared vault volume (once)
docker compose up -d --build
docker compose logs -f       # it will say "NOT authenticated yet"
```

Log in once (persists in the `claude-config` volume):

```bash
docker exec -it claude-remote claude
#   /login   → open the URL, approve on your phone
#   /mcp     → authorise the Gmail + Calendar connectors
#   /exit
docker compose restart
```

After restart the logs should show `starting remote-control session`. Open the
**Claude app** (or claude.ai/code) and the session appears — drive it from your
phone.

## Notes / things to verify on the box

- **Auth: log in once with `/login` (subscription OAuth).** That writes
  `~/.claude/.credentials.json`, which the *same config dir* serves to both the
  remote-control session and headless `claude -p` runs — so headless is
  authenticated for **inference** off the interactive login. (The separate
  `setup-token` env-var token is a different mechanism — inference-only, can't
  do Remote Control — and we don't use it.)
- **Open question, settled empirically (Phase 2 gate):** do the *claude.ai
  Gmail/Calendar connectors* work in a headless `claude -p` run, or only in the
  live session? Once logged in, test it directly:

  ```bash
  docker exec -it claude-remote \
    claude -p "Using the Gmail connector, list the subjects of my 3 most recent emails"
  ```

  - Returns your headers → connectors work headless → Phase 2 = plain cron + `claude -p`.
  - Can't see Gmail → fall back to a local Gmail/Calendar MCP, or inject the
    triage prompt into the live session via a channel.
- **Bind-mount permissions**: the container runs as uid 1000 (`node`). If the
  vault/project files on the Beelink are owned by a different uid, either
  `chown -R 1000:1000` them, or add `user: "<your-uid>:<your-gid>"` to the
  service in `compose.yml`.
- **Vault is a shared volume.** `claude-remote` mounts an external Docker
  volume `obsidian-vault` rather than syncing its own copy. Create it once
  (`docker volume create obsidian-vault`) and have a single `obsidian-headless`
  sync service own the Obsidian Sync login and keep it current (mirrors your
  mias-guide setup); every other container mounts the same volume. Avoids N sync
  clients. The sync service itself isn't in this compose yet — it can live here
  or alongside the existing one.
- **No inbound ports.** Only outbound https is needed; your phone reaches the
  session through Anthropic.
- The exact behaviour of `--remote-control` as a detached container process
  (TTY handling, reconnection after a network blip) is the main thing to
  confirm empirically on first run — the `stdin_open`/`tty` flags and the
  supervisor loop are there to give it the best chance.

## Roadmap

- **Phase 2 — scheduler**: in-container cron firing `claude -p "do my triage"`.
  Open question first: run triage headless via *local* Gmail/Calendar MCPs
  (works without the live session) vs. inject into the live session via a
  channel (e.g. Telegram).
- **Phase 3 — events**: port the existing fswatch → `#claude` vault watcher
  into the container; optionally email-arrival → vault.
