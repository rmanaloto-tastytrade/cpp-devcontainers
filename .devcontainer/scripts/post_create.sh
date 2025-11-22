#!/usr/bin/env bash
set -euo pipefail

CURRENT_USER="${DEVCONTAINER_USER:-$(id -un)}"
CURRENT_GROUP="$(id -gn "$CURRENT_USER" 2>/dev/null || id -gn)"
WORKSPACE_DIR="${WORKSPACE_FOLDER:-/home/${CURRENT_USER}/workspace}"

sudo -n chown -R "${CURRENT_USER}:${CURRENT_GROUP}" /opt/vcpkg || true
sudo -n chown -R "${CURRENT_USER}:${CURRENT_GROUP}" /opt/vcpkg/downloads || true
sudo -n chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "${WORKSPACE_DIR}" || true

if ! command -v clang++-21 >/dev/null 2>&1; then
  echo "[post_create] ERROR: clang++-21 not found in PATH" >&2
  exit 1
fi

SSH_SOURCE="${WORKSPACE_DIR}/.devcontainer/ssh"
SSH_TARGET="$HOME/.ssh"

if compgen -G "$SSH_SOURCE/"'*.pub' > /dev/null; then
  mkdir -p "$SSH_TARGET"
  chmod 700 "$SSH_TARGET"
  cat "$SSH_SOURCE/"*.pub > "$SSH_TARGET/authorized_keys"
  chmod 600 "$SSH_TARGET/authorized_keys"
  echo "[post_create] Installed authorized_keys from $SSH_SOURCE"
else
  echo "[post_create] WARNING: No public keys found under $SSH_SOURCE"
fi

cmake --preset clang-debug
