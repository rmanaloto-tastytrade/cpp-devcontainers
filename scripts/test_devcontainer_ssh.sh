#!/usr/bin/env bash
set -euo pipefail

# Verbose SSH connectivity test to the devcontainer exposed on a remote host.
# Defaults match our current flow (c24s1.ch2:9222, user rmanaloto, key ~/.ssh/id_ed25519).

usage() {
  cat <<'USAGE'
Usage: scripts/test_devcontainer_ssh.sh [options]

Options:
  --host <hostname>        Remote host (default: c24s1.ch2)
  --port <port>            Remote SSH port (default: 9222)
  --user <username>        SSH username (default: rmanaloto)
  --key <path>             Private key path (default: ~/.ssh/id_ed25519)
  --known-hosts <path>     Known hosts file (default: ~/.ssh/known_hosts)
  --clear-known-host       Remove existing host key entry for [host]:[port] before testing
  -h, --help               Show this help
USAGE
}

HOST="c24s1.ch2"
PORT="9222"
USER_NAME="rmanaloto"
KEY_PATH="$HOME/.ssh/id_ed25519"
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
CLEAR_KNOWN_HOST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --key) KEY_PATH="$2"; shift 2 ;;
    --known-hosts) KNOWN_HOSTS_FILE="$2"; shift 2 ;;
    --clear-known-host) CLEAR_KNOWN_HOST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -f "$KEY_PATH" ]] || { echo "[ssh-test] ERROR: key not found: $KEY_PATH" >&2; exit 1; }

echo "[ssh-test] Host: $HOST"
echo "[ssh-test] Port: $PORT"
echo "[ssh-test] User: $USER_NAME"
echo "[ssh-test] Key : $KEY_PATH"
echo "[ssh-test] Known hosts file: $KNOWN_HOSTS_FILE"

echo "[ssh-test] Key fingerprint:"
ssh-keygen -lf "$KEY_PATH" || true

if [[ "$CLEAR_KNOWN_HOST" -eq 1 ]]; then
  echo "[ssh-test] Clearing existing host key for [$HOST]:$PORT from $KNOWN_HOSTS_FILE"
  ssh-keygen -R "[$HOST]:$PORT" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1 || true
fi

SSH_CMD=(ssh -vvv
  -i "$KEY_PATH"
  -o IdentitiesOnly=yes
  -o UserKnownHostsFile="$KNOWN_HOSTS_FILE"
  -o StrictHostKeyChecking=no
  -p "$PORT"
  "${USER_NAME}@${HOST}"
  "echo SSH_OK")

echo "[ssh-test] Executing: ${SSH_CMD[*]}"
if "${SSH_CMD[@]}"; then
  echo "[ssh-test] SUCCESS"
else
  echo "[ssh-test] FAILED" >&2
  exit 1
fi
