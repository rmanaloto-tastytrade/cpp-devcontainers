#!/usr/bin/env bash
set -euo pipefail

CURRENT_USER="${DEVCONTAINER_USER:-$(id -un)}"
CURRENT_GROUP="$(id -gn "$CURRENT_USER" 2>/dev/null || id -gn)"
WORKSPACE_DIR="${WORKSPACE_FOLDER:-/home/${CURRENT_USER}/workspace}"

if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  sudo chown -R "${CURRENT_USER}:${CURRENT_GROUP}" /opt/vcpkg /opt/vcpkg/downloads "${WORKSPACE_DIR}" || true
else
  echo "[post_create] Skipping chown (sudo password required or unavailable)."
fi

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

# Sanitize macOS SSH config (UseKeychain is unsupported on Linux)
SSH_CONFIG_FILE="$SSH_TARGET/config"
if [[ -f "$SSH_CONFIG_FILE" ]] && grep -q "UseKeychain" "$SSH_CONFIG_FILE"; then
  cp "$SSH_CONFIG_FILE" "$SSH_TARGET/config.macbak"
  grep -v "UseKeychain" "$SSH_TARGET/config.macbak" > "$SSH_CONFIG_FILE"
  chmod 600 "$SSH_CONFIG_FILE"
  echo "[post_create] Filtered UseKeychain from ~/.ssh/config (backup at ~/.ssh/config.macbak)."
fi

BUILD_DIR="${WORKSPACE_DIR}/build/clang-debug"
CACHE_FILE="${BUILD_DIR}/CMakeCache.txt"

if [[ -f "$CACHE_FILE" ]]; then
  if ! grep -q "CMAKE_HOME_DIRECTORY:INTERNAL=${WORKSPACE_DIR}" "$CACHE_FILE"; then
    echo "[post_create] Removing stale CMake cache at $BUILD_DIR (workspace path changed)."
    rm -rf "$BUILD_DIR"
  fi
fi

cd "$WORKSPACE_DIR"
cmake --preset clang-debug
