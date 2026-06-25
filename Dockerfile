FROM node:22-bookworm-slim

# git: Claude Code expects it; tini: clean PID 1 (reaps zombies, forwards
# signals so `docker stop` shuts down cleanly); tzdata: local timestamps.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git tini tzdata curl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

ENV TZ=Europe/Paris

COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

# Runs as root: this is a single-purpose container on a personal host with no
# inbound ports, and root avoids uid friction with bind-mounted project/vault
# dirs and the config volume. Login credentials live in /root/.claude (the
# `claude-config` volume) so auth survives restarts.
WORKDIR /project

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
