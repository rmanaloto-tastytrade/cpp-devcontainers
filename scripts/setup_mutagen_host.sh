#!/usr/bin/env bash
set -euo pipefail

# Prepares host-side Mutagen SSH configuration for a given devcontainer env.
# - Writes ~/.mutagen/cpp-devcontainer_ssh_config with ProxyJump to the remote host and port from CONFIG_ENV_FILE.
# - Writes ~/.mutagen.yml (defaults only) and an ssh/scp wrapper under ~/.mutagen/bin that injects that config.
# - Restarts the Mutagen daemon with MUTAGEN_SSH_PATH pointing at the wrapper dir so Mutagen uses the config.
#
# Usage:
#   CONFIG_ENV_FILE=config/env/devcontainer.<host>.gcc14-clang21.env scripts/setup_mutagen_host.sh
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
CONTAINER_USER=${CONTAINER_USER:-${DEVCONTAINER_REMOTE_USER:-${USER}}}
CONTAINER_WORKSPACE=${CONTAINER_WORKSPACE:-"/home/${CONTAINER_USER}/workspace"}
SSH_ALIAS=${MUTAGEN_SSH_ALIAS:-cpp-devcontainer-mutagen}
PROXY_HOST=${MUTAGEN_PROXY_HOST:-${REMOTE_HOST}}
# Append a domain suffix if not already ending with it (user can override/disable)
DOMAIN_SUFFIX=${MUTAGEN_DOMAIN_SUFFIX:-"tastyworks.com"}
if [[ -n "$DOMAIN_SUFFIX" && "$PROXY_HOST" != *".${DOMAIN_SUFFIX}" ]]; then
  PROXY_HOST="${PROXY_HOST}.${DOMAIN_SUFFIX}"
fi

[[ -n "$REMOTE_HOST" ]] || { echo "ERROR: DEVCONTAINER_REMOTE_HOST is required." >&2; exit 1; }
[[ -f "$SSH_KEY" ]] || { echo "ERROR: SSH key not found: $SSH_KEY" >&2; exit 1; }

MUT_DIR="$HOME/.mutagen"
SSH_CFG="$MUT_DIR/cpp-devcontainer_ssh_config"
YML="$HOME/.mutagen.yml"
SSH_BIN="$(command -v ssh)"
WRAP_DIR="$MUT_DIR/bin"
SSH_WRAPPER="$WRAP_DIR/ssh"
SCP_WRAPPER="$WRAP_DIR/scp"
SSH_LOG=${MUTAGEN_SSH_LOG:-"/tmp/mutagen_ssh_invocations.log"}
if [[ -z "$SSH_BIN" ]]; then
  echo "ERROR: ssh not found in PATH" >&2
  exit 1
fi

# Backup existing configs if they exist to avoid destructive overwrite
for file in "$SSH_CFG" "$YML" "$SSH_WRAPPER" "$SCP_WRAPPER"; do
  if [[ -f "$file" ]]; then
    echo "Backing up existing $file to ${file}.bak"
    cp "$file" "${file}.bak"
  fi
done

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

echo "[mutagen-setup] Writing Mutagen config: $YML (portable defaults; ssh command is set via daemon env)"
cat > "$YML" <<EOF
sync:
  defaults:
    watch:
      mode: portable
    symlink:
      mode: portable
    permissions:
      mode: portable
EOF

echo "[mutagen-setup] Writing ssh wrapper for Mutagen: $SSH_WRAPPER (logs to ${SSH_LOG})"
mkdir -p "$WRAP_DIR"
cat > "$SSH_WRAPPER" <<EOF
#!/usr/bin/env bash
LOG_FILE="${SSH_LOG}"
printf '[%s] ssh %s\n' "\$(date +%F@%T)" "\$*" >> "\$LOG_FILE"
exec "${SSH_BIN}" -F "${SSH_CFG}" "\$@"
EOF
chmod +x "$SSH_WRAPPER"

cat > "$SCP_WRAPPER" <<EOF
#!/usr/bin/env bash
exec "${SSH_BIN%/ssh}/scp" -F "${SSH_CFG}" "\$@"
EOF
chmod +x "$SCP_WRAPPER"

echo "[mutagen-setup] Restarting Mutagen daemon to pick up config..."
MUTAGEN_SSH_PATH="$WRAP_DIR" mutagen daemon stop >/dev/null 2>&1 || true
MUTAGEN_SSH_COMMAND="$SSH_WRAPPER" MUTAGEN_SSH_PATH="$WRAP_DIR" mutagen daemon start >/dev/null 2>&1

echo "[mutagen-setup] Done. SSH alias: ${SSH_ALIAS}, config: ${SSH_CFG}, mutagen config: ${YML}"
