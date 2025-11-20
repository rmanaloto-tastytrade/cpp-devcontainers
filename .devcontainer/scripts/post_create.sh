#!/usr/bin/env bash
set -euo pipefail

sudo chown -R slotmap:slotmap /opt/vcpkg
sudo chown -R slotmap:slotmap /workspaces

SSH_SOURCE="/workspaces/SlotMap/.devcontainer/ssh"
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
