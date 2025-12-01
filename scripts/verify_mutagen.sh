#!/usr/bin/env bash
set -euo pipefail

# Validates Mutagen sync end-to-end between the local macOS host and a running
# remote devcontainer over SSH. This assumes you have run:
#   scripts/setup_mutagen_host.sh CONFIG_ENV_FILE=... 
# which writes ~/.mutagen/cpp-devcontainer_ssh_config and ~/.mutagen.yml with the SSH command.
#
# Flow:
# - Creates a temporary session that syncs a small probe directory.
# - Writes probe files on both sides, flushes, verifies both directions, cleans up.
#
# Requirements:
# - mutagen 0.18+ installed locally
# - ~/.mutagen/cpp-devcontainer_ssh_config present (created by setup script) or MUTAGEN_SSH_CONFIG pointing to it
# - Remote devcontainer reachable via the SSH alias defined in that config (default: cpp-devcontainer-mutagen)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_ENV_FILE=${CONFIG_ENV_FILE:-"${ROOT_DIR}/config/env/devcontainer.env"}

[[ -f "$CONFIG_ENV_FILE" ]] || { echo "ERROR: CONFIG_ENV_FILE not found: $CONFIG_ENV_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_ENV_FILE"

MUTAGEN_CMD=${MUTAGEN_BIN:-"mutagen"}
SSH_CFG=${MUTAGEN_SSH_CONFIG:-"$HOME/.mutagen/cpp-devcontainer_ssh_config"}
SSH_ALIAS=${MUTAGEN_SSH_ALIAS:-"cpp-devcontainer-mutagen"}
SSH_WRAPPER=${MUTAGEN_SSH_COMMAND:-"$HOME/.mutagen/bin/ssh"}
[[ -f "$SSH_CFG" ]] || { echo "ERROR: SSH config not found: $SSH_CFG (run scripts/setup_mutagen_host.sh)" >&2; exit 1; }

CONTAINER_USER=${CONTAINER_USER:-${DEVCONTAINER_REMOTE_USER:-${USER}}}
CONTAINER_WORKSPACE=${CONTAINER_WORKSPACE:-"/home/${CONTAINER_USER}/workspace"}

if ! command -v "$MUTAGEN_CMD" >/dev/null 2>&1; then
  echo "ERROR: mutagen binary not found in PATH." >&2
  exit 1
fi

SESSION_NAME="cpp-devcontainer-mutagen-$(date +%s%N)"
PROBE_DIR=".mutagen_probe"
LOCAL_PROBE="${ROOT_DIR}/${PROBE_DIR}"
REMOTE_PROBE="${CONTAINER_WORKSPACE}/${PROBE_DIR}"

MUTAGEN_ENV=(
  MUTAGEN_SSH_COMMAND="$SSH_WRAPPER"
  MUTAGEN_SSH_PATH="$(dirname "$SSH_WRAPPER")"
)

SSH_BASE=(ssh -F "$SSH_CFG" "$SSH_ALIAS")

cleanup() {
  set +e
  env "${MUTAGEN_ENV[@]}" "$MUTAGEN_CMD" sync terminate "$SESSION_NAME" >/dev/null 2>&1 || true
  rm -rf "$LOCAL_PROBE"
  "${SSH_BASE[@]}" "rm -rf '$REMOTE_PROBE'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[mutagen] Ensuring daemon running (uses ~/.mutagen.yml ssh config)..."
env "${MUTAGEN_ENV[@]}" "$MUTAGEN_CMD" daemon start >/dev/null 2>&1 || true

echo "[mutagen] Preparing probe directories..."
rm -rf "$LOCAL_PROBE"
mkdir -p "$LOCAL_PROBE"
"${SSH_BASE[@]}" "mkdir -p '$REMOTE_PROBE' && rm -f '$REMOTE_PROBE'/*" >/dev/null

echo "[mutagen] Creating session $SESSION_NAME..."
env "${MUTAGEN_ENV[@]}" "$MUTAGEN_CMD" sync create \
  --name "$SESSION_NAME" \
  --sync-mode=two-way-resolved \
  --watch-mode=portable \
  "$LOCAL_PROBE" \
  "${SSH_ALIAS}:${REMOTE_PROBE}"

echo "[mutagen] Writing probe files..."
echo "host->remote $(date)" > "${LOCAL_PROBE}/from_host.txt"
"${SSH_BASE[@]}" "echo \"remote->host $(date)\" > '${REMOTE_PROBE}/from_remote.txt'"

echo "[mutagen] Flushing session..."
env "${MUTAGEN_ENV[@]}" "$MUTAGEN_CMD" sync flush "$SESSION_NAME"

echo "[mutagen] Verifying bidirectional sync..."
if [[ ! -f "${LOCAL_PROBE}/from_remote.txt" ]]; then
  echo "ERROR: remote->host probe did not appear locally." >&2
  exit 1
fi

REMOTE_CHECK=$("${SSH_BASE[@]}" "cat '${REMOTE_PROBE}/from_host.txt'" 2>/dev/null || true)
if [[ -z "$REMOTE_CHECK" ]]; then
  echo "ERROR: host->remote probe did not appear on remote." >&2
  exit 1
fi

echo "[mutagen] Session status:"
env "${MUTAGEN_ENV[@]}" "$MUTAGEN_CMD" sync list --long "$SESSION_NAME"

echo "[mutagen] Validation succeeded."
exit 0
