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
LIVE="$HOME/.claude.json"               # where Claude reads/writes it (ephemeral $HOME)
SAVED="$CONFIG_DIR/claude.json.saved"   # persisted copy, inside the $CONFIG_DIR volume

# .claude.json holds BOTH static state (onboarding/theme/folder-trust) AND
# dynamic state we cannot regenerate — notably the interactive /mcp connector
# (Gmail/Calendar) authorisation. It lives OUTSIDE the volume, so a container
# recreate wipes it: the onboarding/trust prompts return (blocking a detached
# session) AND the connectors lose auth. Fix: restore it from the volume on
# boot, re-assert the static flags, then keep saving it back so a later /mcp
# re-auth survives the next recreate.
[ -f "$SAVED" ] && cp -f "$SAVED" "$LIVE"

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
cp -f "$LIVE" "$SAVED" 2>/dev/null || true

# Continuously persist .claude.json changes (e.g. a later interactive /mcp
# re-auth) back into the volume so they survive the next recreate.
( while true; do sleep 10; cp -f "$LIVE" "$SAVED" 2>/dev/null || true; done ) &

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
