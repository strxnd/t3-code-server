FROM docker.io/library/node:24.18.0-bookworm-slim@sha256:b31e7a42fdf8b8aa5f5ed477c72d694301273f1069c5a2f71d53c6482e99a2fc

ARG DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      jq \
      less \
      openssh-client \
      procps \
      ripgrep \
      tini \
      tzdata; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    npm install -g \
      t3@0.0.28 \
      @openai/codex@0.142.5 \
      @anthropic-ai/claude-code@2.1.201 \
      opencode-ai@1.17.13; \
    npm cache clean --force

RUN set -eux; \
    if getent group 1000 >/dev/null; then \
      groupmod --new-name t3 "$(getent group 1000 | cut -d: -f1)"; \
    else \
      groupadd --gid 1000 t3; \
    fi; \
    if getent passwd 1000 >/dev/null; then \
      usermod --login t3 --gid 1000 --home /home/t3 --move-home --shell /bin/bash "$(getent passwd 1000 | cut -d: -f1)"; \
    else \
      useradd --uid 1000 --gid 1000 --create-home --home-dir /home/t3 --shell /bin/bash t3; \
    fi; \
    mkdir -p /home/t3/.codex /home/t3/.local/bin /data/t3 /workspace; \
    chown -R 1000:1000 /home/t3 /data/t3 /workspace

ENV HOME=/home/t3 \
    T3CODE_HOME=/data/t3 \
    CODEX_HOME=/home/t3/.codex \
    PATH=/home/t3/.local/bin:/usr/local/bin:/usr/bin:/bin

USER 1000:1000
WORKDIR /workspace

EXPOSE 3773

ENTRYPOINT ["tini", "--"]
CMD ["t3", "serve", "--host", "0.0.0.0", "--port", "3773", "--base-dir", "/data/t3", "--no-browser", "/workspace"]
