# t3-code-server

Pinned GHCR image for running the official T3 Code headless server in Kubernetes.

Image: `ghcr.io/strxnd/t3-code-server`

## Contents

- Base: `node:24.18.0-bookworm-slim` pinned by digest
- CLIs: `t3@0.0.28`, `@openai/codex@0.142.5`, `@anthropic-ai/claude-code@2.1.201`, `opencode-ai@1.17.13`
- Runtime tools: `ca-certificates`, `curl`, `git`, `gh@2.96.0`, `openssh-client`, `openssh-server`, `bash`, `tini`, `jq`, `ripgrep`, `procps`, `less`, `nano`, `vim-tiny`, `tzdata`
- Non-root user: `t3` with UID/GID `1000:1000`
- Optional SSH sidecar launcher: `/usr/local/bin/t3-sshd`

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

Ports `3773` and `2222` are exposed.

The default user remains `1000:1000`. The optional SSH server is not started unless
`/usr/local/bin/t3-sshd` is run explicitly.

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

Example local SSH sidecar run:

```console
docker run --rm --user 0:0 -p 2222:2222 \
  -e T3CODE_SSH_AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)" \
  -v t3-home:/home/t3 \
  -v "$PWD:/workspace" \
  ghcr.io/strxnd/t3-code-server:latest \
  t3-sshd
```

SSH listens on port `2222` by default. Override it with `T3CODE_SSH_PORT`.

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

## SSH Sidecar

Run the app container normally as UID/GID `1000:1000`. Run a separate SSH sidecar
from the same image as root so OpenSSH can authenticate and switch to user `t3`.
The sidecar should mount the same `/home/t3`, `/workspace`, and `/data` volumes.

Use Kubernetes `args` instead of `command` if you want to keep the image
`tini` entrypoint:

```yaml
containers:
  - name: t3-code
    image: ghcr.io/strxnd/t3-code-server:t3-0.0.28-node-24.18.0-sshd
    ports:
      - name: http
        containerPort: 3773
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
    volumeMounts:
      - name: t3-home
        mountPath: /home/t3
      - name: workspace
        mountPath: /workspace
      - name: data
        mountPath: /data

  - name: t3-ssh
    image: ghcr.io/strxnd/t3-code-server:t3-0.0.28-node-24.18.0-sshd
    args: ["/usr/local/bin/t3-sshd"]
    ports:
      - name: ssh
        containerPort: 2222
    env:
      - name: T3CODE_SSH_AUTHORIZED_KEYS
        valueFrom:
          secretKeyRef:
            name: t3-code-ssh
            key: authorized_keys
      # Optional:
      # - name: T3CODE_SSH_PORT
      #   value: "2222"
    securityContext:
      runAsUser: 0
      runAsGroup: 0
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: false
      capabilities:
        drop: ["ALL"]
        add:
          - CHOWN
          - DAC_OVERRIDE
          - FOWNER
          - SETGID
          - SETUID
          - SYS_CHROOT
    volumeMounts:
      - name: t3-home
        mountPath: /home/t3
      - name: workspace
        mountPath: /workspace
      - name: data
        mountPath: /data
```

`t3-sshd` writes `T3CODE_SSH_AUTHORIZED_KEYS`, when present, to
`/home/t3/.ssh/authorized_keys` with mode `600` and owner `t3:t3`. If the env var
is not set, an existing `/home/t3/.ssh/authorized_keys` file is used. Password and
keyboard-interactive authentication are disabled.

Host keys are generated at runtime under `/home/t3/.ssh/sshd/` and reused across
pod restarts when `/home/t3` is persistent. No host private keys, user private
keys, passwords, or authorized keys are baked into the image.

The generated SSH config uses `internal-sftp`, allows TCP forwarding, disables
PAM, disables root login, and restricts login to user `t3`.

## Publishing

The GitHub Actions workflow builds and smoke-tests the image, then pushes:

- `ghcr.io/strxnd/t3-code-server:t3-0.0.28-node-24.18.0-sshd`
- `ghcr.io/strxnd/t3-code-server:sha-<shortsha>`
- `ghcr.io/strxnd/t3-code-server:latest`

It uses `GITHUB_TOKEN` with `packages: write`. After the first push, make the GHCR package public in the GitHub package settings.
