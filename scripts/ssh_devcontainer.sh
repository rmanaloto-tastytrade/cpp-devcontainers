#!/usr/bin/env bash
set -euo pipefail

# Connect to a running devcontainer via SSH using values from a config env file.
# - Cleans the relevant known_hosts entry for the container port before connecting.
# - Supports ProxyJump through the remote host (default) or direct localhost (if already on the host).
#
# Usage:
#   CONFIG_ENV_FILE=config/env/devcontainer.gcc14-clang21.env scripts/ssh_devcontainer.sh [ssh args/command...]
# Defaults to config/env/devcontainer.env and opens an interactive shell.

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-"$REPO_ROOT/config/env/devcontainer.env"}"

if [[ ! -f "$CONFIG_ENV_FILE" ]]; then
  echo "[ssh-devcontainer] ERROR: Config file not found: $CONFIG_ENV_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_ENV_FILE"

REMOTE_HOST=${DEVCONTAINER_REMOTE_HOST:?set DEVCONTAINER_REMOTE_HOST in env file}
REMOTE_USER=${DEVCONTAINER_REMOTE_USER:?set DEVCONTAINER_REMOTE_USER in env file}
SSH_PORT=${DEVCONTAINER_SSH_PORT:-9222}
SSH_KEY=${DEVCONTAINER_SSH_KEY:-${DEVCONTAINER_SSH_KEY_PATH:-${SSH_KEY_PATH:-"$HOME/.ssh/id_ed25519"}}}
CONTAINER_USER=${CONTAINER_USER:-${DEVCONTAINER_USER:-${REMOTE_USER}}}

if [[ ! -f "$SSH_KEY" ]]; then
  echo "[ssh-devcontainer] ERROR: SSH key not found at $SSH_KEY" >&2
  exit 1
fi

echo "[ssh-devcontainer] Using config: $CONFIG_ENV_FILE"
echo "[ssh-devcontainer] Remote host/user: ${REMOTE_HOST}/${REMOTE_USER}"
echo "[ssh-devcontainer] Container user: ${CONTAINER_USER}"
echo "[ssh-devcontainer] Port: ${SSH_PORT}"

# Clean stale host key entries for the container port on localhost.
ssh-keygen -R "[127.0.0.1]:${SSH_PORT}" >/dev/null 2>&1 || true
ssh-keygen -R "[localhost]:${SSH_PORT}" >/dev/null 2>&1 || true

SSH_BASE_OPTS=(
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
)

# Decide whether to ProxyJump (default) or connect locally (if already on the host).
if [[ "${ON_REMOTE_HOST:-0}" == "1" ]]; then
  SSH_CMD=(ssh "${SSH_BASE_OPTS[@]}" -p "${SSH_PORT}" "${CONTAINER_USER}@127.0.0.1")
else
  SSH_CMD=(ssh "${SSH_BASE_OPTS[@]}" -J "${REMOTE_USER}@${REMOTE_HOST}" -p "${SSH_PORT}" "${CONTAINER_USER}@127.0.0.1")
fi

if [[ $# -gt 0 ]]; then
  exec "${SSH_CMD[@]}" "$@"
else
  exec "${SSH_CMD[@]}"
fi
