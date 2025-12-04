#!/usr/bin/env bash
set -euo pipefail

CURRENT_USER="${DEVCONTAINER_USER:-$(id -un)}"
CURRENT_GROUP="$(id -gn "$CURRENT_USER" 2>/dev/null || id -gn)"
WORKSPACE_DIR="${WORKSPACE_FOLDER:-/home/${CURRENT_USER}/workspace}"
CACHE_ROOT="/cppdev-cache"
CCACHE_DIR="${CCACHE_DIR:-${CACHE_ROOT}/ccache}"
SCCACHE_DIR="${SCCACHE_DIR:-${CACHE_ROOT}/sccache}"
VCPKG_DOWNLOADS="${VCPKG_DOWNLOADS:-${CACHE_ROOT}/vcpkg-downloads}"
VCPKG_BINARY_CACHE="${VCPKG_DEFAULT_BINARY_CACHE:-${CACHE_ROOT}/vcpkg-archives}"
VCPKG_PACKAGES="${VCPKG_PACKAGES:-${CACHE_ROOT}/vcpkg-packages}"
VCPKG_BUILDTREES="${VCPKG_BUILDTREES:-${CACHE_ROOT}/vcpkg-buildtrees}"
PERSISTENT_TMP="${TMPDIR:-${CACHE_ROOT}/tmp}"

if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  sudo mkdir -p /opt/vcpkg
  sudo chown -R "${CURRENT_USER}:${CURRENT_GROUP}" /opt/vcpkg "${WORKSPACE_DIR}" || true
else
  echo "[post_create] Skipping chown (sudo password required or unavailable)."
fi

echo "[post_create] Preparing persistent cache root at ${CACHE_ROOT}..."
mkdir -p "${CACHE_ROOT}"/{ccache,sccache,vcpkg-downloads,vcpkg-archives,tmp}
mkdir -p "${VCPKG_PACKAGES}" "${VCPKG_BUILDTREES}"
chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "${CACHE_ROOT}"

# Point vcpkg downloads/binary cache at the persistent volume
mkdir -p /opt/vcpkg
if [ -d /opt/vcpkg/downloads ] || [ -L /opt/vcpkg/downloads ]; then
  rm -rf /opt/vcpkg/downloads
fi
ln -snf "${VCPKG_DOWNLOADS}" /opt/vcpkg/downloads
mkdir -p "${VCPKG_BINARY_CACHE}"
chown -R "${CURRENT_USER}:${CURRENT_GROUP}" /opt/vcpkg "${VCPKG_DOWNLOADS}" "${VCPKG_BINARY_CACHE}"
# Persist vcpkg packages/buildtrees
if [ -d /opt/vcpkg/packages ] || [ -L /opt/vcpkg/packages ]; then
  rm -rf /opt/vcpkg/packages
fi
if [ -d /opt/vcpkg/buildtrees ] || [ -L /opt/vcpkg/buildtrees ]; then
  rm -rf /opt/vcpkg/buildtrees
fi
ln -snf "${VCPKG_PACKAGES}" /opt/vcpkg/packages
ln -snf "${VCPKG_BUILDTREES}" /opt/vcpkg/buildtrees
chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "${VCPKG_PACKAGES}" "${VCPKG_BUILDTREES}"

# Ensure ccache/sccache dirs are owned and writable
mkdir -p "${CCACHE_DIR}" "${SCCACHE_DIR}"
chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "${CCACHE_DIR}" "${SCCACHE_DIR}"

# Make /tmp persistent via symlink into the cache volume if empty
if [ ! -L /tmp ] && [ -z "$(ls -A /tmp)" ]; then
  rm -rf /tmp
  ln -snf "${PERSISTENT_TMP}" /tmp
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
  if ls "$SSH_TARGET"/id_* 2>/dev/null | grep -v '\.pub$' > /dev/null; then
    echo "[post_create] WARNING: Private keys detected in $SSH_TARGET - will not modify them"
  fi
  if [[ -f "$SSH_TARGET/authorized_keys" ]]; then
    cp "$SSH_TARGET/authorized_keys" "$SSH_TARGET/authorized_keys.backup.$(date +%Y%m%d-%H%M%S)"
    echo "[post_create] Backed up existing authorized_keys"
  fi
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

# Force GitHub SSH over 443 inside the container (port 22 is often blocked on remote hosts).
# See: https://docs.github.com/en/authentication/troubleshooting-ssh/using-ssh-over-the-https-port
{
  echo ""
  echo "# Added by post_create.sh for cpp-devcontainer: use GitHub SSH over 443"
  echo "Host github.com"
  echo "  Hostname ssh.github.com"
  echo "  Port 443"
  echo "  User git"
  echo "  CanonicalizeHostname no  # avoid company DNS suffixes (e.g., github.com.tastyworks.com)"
  echo "  StrictHostKeyChecking accept-new  # allow first connect to add host key without interactivity"
  echo "  UserKnownHostsFile ~/.ssh/known_hosts"
} >> "$SSH_CONFIG_FILE"
chmod 600 "$SSH_CONFIG_FILE"

BUILD_DIR="${WORKSPACE_DIR}/build/clang-debug"
CACHE_FILE="${BUILD_DIR}/CMakeCache.txt"

# Remove any stale CMake build dirs copied from other hosts (path mismatch).
BUILD_ROOT="${WORKSPACE_DIR}/build"
if [[ -d "$BUILD_ROOT" ]]; then
  while IFS= read -r cache; do
    dir="$(dirname "$cache")"
    if ! grep -q "CMAKE_HOME_DIRECTORY:INTERNAL=${WORKSPACE_DIR}" "$cache"; then
      echo "[post_create] Removing stale CMake cache at $dir (workspace path changed)."
      rm -rf "$dir"
    fi
  done < <(find "$BUILD_ROOT" -maxdepth 2 -name CMakeCache.txt 2>/dev/null)
fi

if [[ -f "$CACHE_FILE" ]]; then
  if ! grep -q "CMAKE_HOME_DIRECTORY:INTERNAL=${WORKSPACE_DIR}" "$CACHE_FILE"; then
    echo "[post_create] Removing stale CMake cache at $BUILD_DIR (workspace path changed)."
    rm -rf "$BUILD_DIR"
  fi
fi

cd "$WORKSPACE_DIR"
PREFERRED_PRESET="${CMAKE_PRESET:-clang21-debug}"
if ! cmake --list-presets | grep -q "\"${PREFERRED_PRESET}\""; then
  for candidate in clang21-debug clang22-debug gcc15-debug gcc14-debug clang-p2996-debug; do
    if cmake --list-presets | grep -q "\"${candidate}\""; then
      PREFERRED_PRESET="${candidate}"
      break
    fi
  done
fi
cmake --preset "${PREFERRED_PRESET}"
