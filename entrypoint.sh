#!/usr/bin/env bash
# PID-1 (under tini) supervisor for the always-on Remote Control session.
#
# First boot the volume is empty → no credentials → we can't start a session.
# So: if unauthenticated, print the one-time login instructions and idle, so
# you can `docker exec` in and run `claude` → /login (and /mcp to authorise the
# Gmail/Calendar connectors) once. Those write into the mounted ~/.claude
# volume and persist. After that, every (re)start runs the session directly.
set -uo pipefail

CONFIG_DIR="$HOME/.claude"
CREDS="$CONFIG_DIR/.credentials.json"

# $HOME/.claude.json holds onboarding/theme/folder-trust state but lives OUTSIDE
# the $CONFIG_DIR volume, so a container *recreate* wipes it (and a recreated
# container gets a fresh machine-id, which also resets onboarding) — throwing a
# detached Remote Control session back into the onboarding + folder-trust
# prompts, which block on input and never reach "active". These flags are
# static, so just (re)assert them on every boot, before Claude starts.
node -e '
  const fs = require("fs"), p = process.env.HOME + "/.claude.json";
  let d = {}; try { d = JSON.parse(fs.readFileSync(p, "utf8")); } catch (e) {}
  d.hasCompletedOnboarding = true;
  d.lastOnboardingVersion = d.lastOnboardingVersion || "0.2.56";
  d.theme = d.theme || "dark";
  d.projects = d.projects || {};
  d.projects["/project"] = Object.assign(
    { hasTrustDialogAccepted: true, hasCompletedProjectOnboarding: true },
    d.projects["/project"]
  );
  fs.writeFileSync(p, JSON.stringify(d, null, 2));
' || echo "[entrypoint] warning: could not pre-seed .claude.json flags"

if [[ ! -f "$CREDS" ]]; then
  cat <<EOF
────────────────────────────────────────────────────────────────────
Claude Code is NOT authenticated yet (no $CREDS).

Log in once — it persists in the mounted ~/.claude volume:

  docker exec -it claude-remote claude
    → /login           (opens a URL; approve on your phone/laptop)
    → /mcp             (authorise the Gmail / Calendar connectors)
    → /exit

Then restart the container:

  docker compose restart

Idling so you can exec in...
────────────────────────────────────────────────────────────────────
EOF
  exec sleep infinity
fi

echo "[entrypoint] authenticated — starting remote-control session"

# Supervise: if the session ever drops (network blip, crash), restart it.
# Container-level `restart: unless-stopped` covers process death; this loop
# covers a clean exit of the session without taking the container down.
while true; do
  claude --remote-control --add-dir /vault --name "${SESSION_NAME:-life-ops-agent}"
  rc=$?
  echo "[entrypoint] remote-control exited (rc=$rc); restarting in 5s"
  sleep 5
done
