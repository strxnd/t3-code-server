#!/usr/bin/env bash
set -euxo pipefail

image="${1:?usage: smoke-test-image.sh IMAGE}"

timeout 30s docker run --rm "$image" t3 --version
timeout 30s docker run --rm "$image" codex --version
timeout 30s docker run --rm "$image" claude --version
timeout 30s docker run --rm "$image" opencode --version
timeout 30s docker run --rm "$image" gh --version
timeout 30s docker run --rm "$image" git --version
timeout 30s docker run --rm "$image" nano --version
timeout 30s docker run --rm "$image" vi --version
timeout 30s docker run --rm "$image" sh -c 'test "$(id -u):$(id -g)" = "1000:1000"'
timeout 30s docker run --rm "$image" sh -c 'for key in /etc/ssh/ssh_host_*_key; do [ ! -e "$key" ] || exit 1; done'
timeout 30s docker run --rm --user 0:0 "$image" t3-sshd -t

tmpdir="$(mktemp -d)"
server_cid=""
ssh_cid=""
trap 'for cid in "$server_cid" "$ssh_cid"; do if [[ -n "$cid" ]]; then docker rm -f "$cid" >/dev/null 2>&1 || true; fi; done; rm -rf "$tmpdir"' EXIT

server_cid="$(docker run -d --rm -p 127.0.0.1::3773 "$image")"
server_port="$(docker port "$server_cid" 3773/tcp | sed 's/.*://')"
server_ready="false"
for _ in $(seq 1 30); do
  if curl --max-time 2 -fsS "http://127.0.0.1:${server_port}/" >/dev/null; then
    server_ready="true"
    break
  fi
  sleep 1
done
[[ "$server_ready" == "true" ]]
docker rm -f "$server_cid"
server_cid=""

ssh-keygen -q -t ed25519 -N '' -C smoke -f "$tmpdir/id_ed25519"
ssh_cid="$(
  docker run -d --rm --user 0:0 \
    -e T3CODE_SSH_AUTHORIZED_KEYS="$(cat "$tmpdir/id_ed25519.pub")" \
    -p 127.0.0.1::2222 \
    "$image" t3-sshd
)"
port="$(docker port "$ssh_cid" 2222/tcp | sed 's/.*://')"

ssh_ready="false"
for _ in $(seq 1 30); do
  if ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile="$tmpdir/known_hosts" \
    -i "$tmpdir/id_ed25519" \
    -p "$port" \
    t3@127.0.0.1 \
    'test "$HOME" = /home/t3 && test "$(id -u):$(id -g)" = "1000:1000"'
  then
    ssh_ready="true"
    break
  fi
  sleep 1
done
[[ "$ssh_ready" == "true" ]]

ssh \
  -o BatchMode=yes \
  -o ConnectTimeout=5 \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile="$tmpdir/known_hosts" \
  -i "$tmpdir/id_ed25519" \
  -p "$port" \
  t3@127.0.0.1 \
  'test "$HOME" = /home/t3 && pwd'

printf 'pwd\nquit\n' | sftp \
  -b - \
  -o BatchMode=yes \
  -o ConnectTimeout=5 \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile="$tmpdir/known_hosts" \
  -i "$tmpdir/id_ed25519" \
  -P "$port" \
  t3@127.0.0.1
