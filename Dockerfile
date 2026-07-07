FROM docker.io/library/node:24.18.0-bookworm-slim@sha256:b31e7a42fdf8b8aa5f5ed477c72d694301273f1069c5a2f71d53c6482e99a2fc AS build

ARG DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      g++ \
      make \
      python3; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    npm install -g \
      t3@0.0.28 \
      @openai/codex@0.142.5 \
      @anthropic-ai/claude-code@2.1.201 \
      opencode-ai@1.17.13; \
    npm cache clean --force

FROM docker.io/library/node:24.18.0-bookworm-slim@sha256:b31e7a42fdf8b8aa5f5ed477c72d694301273f1069c5a2f71d53c6482e99a2fc

ARG DEBIAN_FRONTEND=noninteractive
ARG GH_VERSION=2.96.0
ARG GH_DEB_SHA256=11a731f4e0ca8c3db96ef6d2cc404dcab3d78247ce0e07c53e07117e7627d6a1

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      jq \
      less \
      nano \
      openssh-client \
      openssh-server \
      procps \
      ripgrep \
      tini \
      tzdata \
      vim-tiny; \
    curl -fsSLo /tmp/gh.deb "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.deb"; \
    echo "${GH_DEB_SHA256}  /tmp/gh.deb" | sha256sum -c -; \
    apt-get install -y --no-install-recommends /tmp/gh.deb; \
    rm -f /tmp/gh.deb; \
    rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub; \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=build /usr/local/bin /usr/local/bin
COPY t3-sshd /usr/local/bin/t3-sshd

RUN set -eux; \
    chmod 0755 /usr/local/bin/t3-sshd; \
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
    chown -R 1000:1000 /home/t3 /data/t3 /workspace; \
    passwd --delete t3; \
    printf '%s\n' \
      'export T3CODE_HOME="${T3CODE_HOME:-/data/t3}"' \
      'export CODEX_HOME="${CODEX_HOME:-/home/t3/.codex}"' \
      'case ":$PATH:" in' \
      '  *:/usr/local/bin:*) ;;' \
      '  *) export PATH="/usr/local/bin:$PATH" ;;' \
      'esac' \
      'case ":$PATH:" in' \
      '  *:/home/t3/.local/bin:*) ;;' \
      '  *) export PATH="/home/t3/.local/bin:$PATH" ;;' \
      'esac' \
      > /etc/profile.d/t3-code-server.sh

ENV HOME=/home/t3 \
    T3CODE_HOME=/data/t3 \
    CODEX_HOME=/home/t3/.codex \
    PATH=/home/t3/.local/bin:/usr/local/bin:/usr/bin:/bin

USER 1000:1000
WORKDIR /workspace

EXPOSE 3773 2222

ENTRYPOINT ["tini", "--"]
CMD ["t3", "serve", "--host", "0.0.0.0", "--port", "3773", "--base-dir", "/data/t3", "--no-browser", "/workspace"]
