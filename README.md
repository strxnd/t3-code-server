# t3-code-server

Pinned GHCR image for running the official T3 Code headless server in Kubernetes.

Image: `ghcr.io/strxnd/t3-code-server`

## Contents

- Base: `node:24.18.0-bookworm-slim` pinned by digest
- CLIs: `t3@0.0.28`, `@openai/codex@0.142.5`, `@anthropic-ai/claude-code@2.1.201`, `opencode-ai@1.17.13`
- Runtime tools: `ca-certificates`, `curl`, `git`, `gh@2.96.0`, `openssh-client`, `bash`, `tini`, `jq`, `ripgrep`, `procps`, `less`, `nano`, `vim-tiny`, `tzdata`
- Non-root user: `t3` with UID/GID `1000:1000`

Cursor CLI is not installed by default. It can be added later, but its official install path is less pin-friendly than the pinned npm CLIs above.

## Default Command

```console
t3 serve --host 0.0.0.0 --port 3773 --base-dir /data/t3 --no-browser /workspace
```

The container uses:

```dockerfile
ENTRYPOINT ["tini", "--"]
CMD ["t3", "serve", "--host", "0.0.0.0", "--port", "3773", "--base-dir", "/data/t3", "--no-browser", "/workspace"]
```

Port `3773` is exposed.

## Build and Run

```console
docker build -t ghcr.io/strxnd/t3-code-server:test .
docker run --rm ghcr.io/strxnd/t3-code-server:test t3 --version
```

Example local server run:

```console
docker run --rm -p 3773:3773 \
  -v t3-data:/data/t3 \
  -v t3-home:/home/t3 \
  -v "$PWD:/workspace" \
  ghcr.io/strxnd/t3-code-server:latest
```

## Kubernetes Mounts

Mount persistent storage for:

- `/data/t3`: T3 state
- `/home/t3`: agent and provider auth state
- `/workspace`: cloned repos and worktrees

Run provider authentication inside a Kubernetes pod:

```console
codex login
claude auth login
opencode auth login
```

Create the initial T3 pairing token:

```console
t3 auth pairing create --base-dir /data/t3 --base-url https://t3-code.example.com --ttl 30m --label initial-admin
```

Pairing tokens and provider auth outputs are secrets. Do not commit them to Git, bake them into the image, or put them in plain-text manifests.

## Publishing

The GitHub Actions workflow builds and smoke-tests the image, then pushes:

- `ghcr.io/strxnd/t3-code-server:t3-0.0.28-node-24.18.0`
- `ghcr.io/strxnd/t3-code-server:sha-<shortsha>`
- `ghcr.io/strxnd/t3-code-server:latest`

It uses `GITHUB_TOKEN` with `packages: write`. After the first push, make the GHCR package public in the GitHub package settings.
