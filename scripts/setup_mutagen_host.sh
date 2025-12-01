#!/usr/bin/env bash
set -euo pipefail

# Prepares host-side Mutagen SSH configuration for a given devcontainer env.
# - Writes ~/.mutagen/slotmap_ssh_config with ProxyJump to the remote host and port from CONFIG_ENV_FILE.
# - Writes ~/.mutagen.yml (backing up any existing file) to force sync.ssh.command to use that config.
# - Restarts the Mutagen daemon to pick up the new command.
#
# Usage:
#   CONFIG_ENV_FILE=config/env/devcontainer.c0903.gcc14-clang21.env scripts/setup_mutagen_host.sh
#
# After running, use scripts/verify_mutagen.sh (and verify_devcontainer.sh with REQUIRE_MUTAGEN=1).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_ENV_FILE=${CONFIG_ENV_FILE:-"${ROOT_DIR}/config/env/devcontainer.env"}

[[ -f "$CONFIG_ENV_FILE" ]] || { echo "ERROR: CONFIG_ENV_FILE not found: $CONFIG_ENV_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_ENV_FILE"

REMOTE_HOST=${DEVCONTAINER_REMOTE_HOST:-}
REMOTE_USER=${DEVCONTAINER_REMOTE_USER:-$USER}
SSH_PORT=${DEVCONTAINER_SSH_PORT:-9222}
SSH_KEY=${DEVCONTAINER_SSH_KEY:-"$HOME/.ssh/id_ed25519"}
CONTAINER_USER=${CONTAINER_USER:-slotmap}
CONTAINER_WORKSPACE=${CONTAINER_WORKSPACE:-"/home/${CONTAINER_USER}/workspace"}
SSH_ALIAS=${MUTAGEN_SSH_ALIAS:-slotmap-mutagen}
PROXY_HOST=${MUTAGEN_PROXY_HOST:-${REMOTE_HOST}}
# Append a domain suffix if not already fully qualified (user can override)
DOMAIN_SUFFIX=${MUTAGEN_DOMAIN_SUFFIX:-"example.com"}
if [[ "$PROXY_HOST" != *"."* && -n "$DOMAIN_SUFFIX" ]]; then
  PROXY_HOST="${PROXY_HOST}.${DOMAIN_SUFFIX}"
fi

[[ -n "$REMOTE_HOST" ]] || { echo "ERROR: DEVCONTAINER_REMOTE_HOST is required." >&2; exit 1; }
[[ -f "$SSH_KEY" ]] || { echo "ERROR: SSH key not found: $SSH_KEY" >&2; exit 1; }

MUT_DIR="$HOME/.mutagen"
SSH_CFG="$MUT_DIR/slotmap_ssh_config"
YML="$HOME/.mutagen.yml"

mkdir -p "$MUT_DIR"

echo "[mutagen-setup] Writing SSH config: $SSH_CFG"
cat > "$SSH_CFG" <<EOF
Host ${SSH_ALIAS}
  HostName 127.0.0.1
  Port ${SSH_PORT}
  User ${CONTAINER_USER}
  IdentityFile ${SSH_KEY}
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  CanonicalizeHostname yes
  CanonicalDomains tastyworks.com
  CanonicalizeFallbackLocal yes
  ProxyJump ${REMOTE_USER}@${PROXY_HOST}
EOF

echo "[mutagen-setup] Writing Mutagen config: $YML (minimal defaults)"
cat > "$YML" <<'EOF'
sync:
  defaults: {}
EOF

echo "[mutagen-setup] Restarting Mutagen daemon to pick up config..."
mutagen daemon stop >/dev/null 2>&1 || true
mutagen daemon start >/dev/null 2>&1

echo "[mutagen-setup] Done. SSH alias: ${SSH_ALIAS}, config: ${SSH_CFG}, mutagen config: ${YML}"
