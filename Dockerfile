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

# The node image ships a uid-1000 `node` user. Run as that (Claude Code warns
# when run as root) and keep its config — including the login credentials — in
# /home/node/.claude, which compose mounts as a named volume so auth survives
# rebuilds and restarts.
USER node
WORKDIR /project

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
