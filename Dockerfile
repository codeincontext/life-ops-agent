FROM node:22-bookworm-slim

# git: Claude Code expects it; tini: clean PID 1 (reaps zombies, forwards
# signals so `docker stop` shuts down cleanly); tzdata: local timestamps.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git tini tzdata curl \
    && rm -rf /var/lib/apt/lists/*

# claude-code: the agent. obsidian-headless (`ob`): a CLI Obsidian Sync client
# used to keep /vault synced with your Obsidian account (no Electron/GUI needed).
RUN npm install -g @anthropic-ai/claude-code obsidian-headless

ENV TZ=Europe/Paris

COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

# Run as the image's uid-1000 `node` user (not root). Pre-create the dirs that
# get named volumes mounted onto them and chown to node, so those volumes
# initialise node-owned — letting the session persist its login (/home/node/.claude)
# and write the vault (/vault) without running privileged.
RUN mkdir -p /home/node/.claude /vault /home/node/.config/obsidian-headless \
    && chown -R node:node /home/node/.claude /vault /home/node/.config
USER node
WORKDIR /project

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
