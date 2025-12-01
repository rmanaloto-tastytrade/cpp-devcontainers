#!/usr/bin/env bash
set -euo pipefail

# Validates Mutagen sync end-to-end between the local macOS host and a running
# remote devcontainer over SSH. This assumes you have run:
#   scripts/setup_mutagen_host.sh CONFIG_ENV_FILE=... 
# which writes ~/.mutagen/slotmap_ssh_config and ~/.mutagen.yml with the SSH command.
#
# Flow:
# - Creates a temporary session that syncs a small probe directory.
# - Writes probe files on both sides, flushes, verifies both directions, cleans up.
#
# Requirements:
# - mutagen 0.18+ installed locally
# - ~/.mutagen/slotmap_ssh_config present (created by setup script) or MUTAGEN_SSH_CONFIG pointing to it
# - Remote devcontainer reachable via the SSH alias defined in that config (default: slotmap-mutagen)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_ENV_FILE=${CONFIG_ENV_FILE:-"${ROOT_DIR}/config/env/devcontainer.env"}

[[ -f "$CONFIG_ENV_FILE" ]] || { echo "ERROR: CONFIG_ENV_FILE not found: $CONFIG_ENV_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_ENV_FILE"

REMOTE_HOST_RAW=${DEVCONTAINER_REMOTE_HOST:-}
REMOTE_USER=${DEVCONTAINER_REMOTE_USER:-$USER}
SSH_PORT=${DEVCONTAINER_SSH_PORT:-9222}
SSH_KEY=${DEVCONTAINER_SSH_KEY:-"$HOME/.ssh/id_ed25519"}
PROXY_HOST=${REMOTE_HOST_RAW}
DOMAIN_SUFFIX=${MUTAGEN_DOMAIN_SUFFIX:-"example.com"}
if [[ "$PROXY_HOST" != *"."* && -n "$DOMAIN_SUFFIX" ]]; then
  PROXY_HOST="${PROXY_HOST}.${DOMAIN_SUFFIX}"
fi
MUTAGEN_SSH_CONFIG=${MUTAGEN_SSH_CONFIG:-""}
MUTAGEN_CMD=${MUTAGEN_BIN:-"mutagen"}

CONTAINER_USER=${CONTAINER_USER:-slotmap}
CONTAINER_WORKSPACE=${CONTAINER_WORKSPACE:-"/home/${CONTAINER_USER}/workspace"}

if ! command -v "$MUTAGEN_CMD" >/dev/null 2>&1; then
  echo "ERROR: mutagen binary not found in PATH." >&2
  exit 1
fi

SESSION_NAME="slotmap-mutagen-$(date +%s%N)"
PROBE_DIR=".mutagen_probe"
LOCAL_PROBE="${ROOT_DIR}/${PROBE_DIR}"
REMOTE_PROBE="${CONTAINER_WORKSPACE}/${PROBE_DIR}"

SSH_BASE=(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -J "${REMOTE_USER}@${PROXY_HOST}" -p "$SSH_PORT" "${CONTAINER_USER}@127.0.0.1")
WRAP_LOG="/tmp/mutagen_ssh_invocations.log"
SSH_WRAPPER="$(mktemp)"
cat > "$SSH_WRAPPER" <<EOF
#!/usr/bin/env bash
echo "\$0 \$@" >> "$WRAP_LOG"
exec /usr/bin/ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -J "${REMOTE_USER}@${PROXY_HOST}" -p "$SSH_PORT" "\$@"
EOF
chmod +x "$SSH_WRAPPER"
MUTAGEN_SSH_COMMAND=${MUTAGEN_SSH_COMMAND:-"$SSH_WRAPPER"}

cleanup() {
  set +e
  "$MUTAGEN_CMD" sync terminate "$SESSION_NAME" >/dev/null 2>&1 || true
  rm -rf "$LOCAL_PROBE"
  "${SSH_BASE[@]}" "rm -rf '$REMOTE_PROBE'" >/dev/null 2>&1 || true
  rm -f "$SSH_WRAPPER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[mutagen] Ensuring daemon running with configured SSH command..."
MUTAGEN_SSH_COMMAND="$MUTAGEN_SSH_COMMAND" "$MUTAGEN_CMD" daemon stop >/dev/null 2>&1 || true
MUTAGEN_SSH_COMMAND="$MUTAGEN_SSH_COMMAND" "$MUTAGEN_CMD" daemon start >/dev/null 2>&1 || true

echo "[mutagen] Preparing probe directories..."
rm -rf "$LOCAL_PROBE"
mkdir -p "$LOCAL_PROBE"
"${SSH_BASE[@]}" "mkdir -p '$REMOTE_PROBE' && rm -f '$REMOTE_PROBE'/*" >/dev/null

echo "[mutagen] Creating session $SESSION_NAME..."
MUTAGEN_SSH_COMMAND="$MUTAGEN_SSH_COMMAND" "$MUTAGEN_CMD" sync create \
  --name "$SESSION_NAME" \
  --sync-mode=two-way-resolved \
  --watch-mode=portable \
  "$LOCAL_PROBE" \
  "${CONTAINER_USER}@127.0.0.1:${REMOTE_PROBE}"

echo "[mutagen] Writing probe files..."
echo "host->remote $(date)" > "${LOCAL_PROBE}/from_host.txt"
"${SSH_BASE[@]}" "echo \"remote->host $(date)\" > '${REMOTE_PROBE}/from_remote.txt'"

echo "[mutagen] Flushing session..."
MUTAGEN_SSH_COMMAND="$MUTAGEN_SSH_COMMAND" "$MUTAGEN_CMD" sync flush "$SESSION_NAME"

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
MUTAGEN_SSH_COMMAND="$MUTAGEN_SSH_COMMAND" "$MUTAGEN_CMD" sync list --verbose "$SESSION_NAME"

echo "[mutagen] Validation succeeded."
exit 0
