#!/usr/bin/env bash
set -euo pipefail

CURRENT_USER="${DEVCONTAINER_USER:-$(id -un)}"
CURRENT_GROUP="$(id -gn "$CURRENT_USER" 2>/dev/null || id -gn)"
WORKSPACE_DIR="${WORKSPACE_FOLDER:-/home/${CURRENT_USER}/workspace}"
CLANG_VARIANT="${CLANG_VARIANT:-21}"
CACHE_ROOT="/cppdev-cache"
CCACHE_DIR="${CCACHE_DIR:-${CACHE_ROOT}/ccache}"
SCCACHE_DIR="${SCCACHE_DIR:-${CACHE_ROOT}/sccache}"
VCPKG_DOWNLOADS="${VCPKG_DOWNLOADS:-${CACHE_ROOT}/vcpkg-downloads}"
VCPKG_BINARY_CACHE="${VCPKG_DEFAULT_BINARY_CACHE:-${CACHE_ROOT}/vcpkg-archives}"
PERSISTENT_TMP="${TMPDIR:-${CACHE_ROOT}/tmp}"
VCPKG_REPO="${VCPKG_REPO:-${CACHE_ROOT}/vcpkg-repo}"

if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  sudo mkdir -p /opt/vcpkg
  sudo chown -R "${CURRENT_USER}:${CURRENT_GROUP}" /opt/vcpkg "${WORKSPACE_DIR}" || true
else
  echo "[post_create] Skipping chown (sudo password required or unavailable)."
fi
if [ -d /opt/vcpkg ] && [ ! -L /opt/vcpkg ]; then
  echo "[post_create] Replacing /opt/vcpkg directory with symlink to ${VCPKG_REPO}..."
  if command -v sudo >/dev/null 2>&1; then
    sudo -n rm -rf /opt/vcpkg || rm -rf /opt/vcpkg
  else
    rm -rf /opt/vcpkg
  fi
fi

echo "[post_create] Preparing persistent cache root at ${CACHE_ROOT}..."
mkdir -p "${CACHE_ROOT}"/{ccache,sccache,vcpkg-downloads,vcpkg-archives,tmp}
chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "${CACHE_ROOT}"

# Prepare vcpkg caches on the persistent volume (env variables point to these)
mkdir -p "${VCPKG_DOWNLOADS}" "${VCPKG_BINARY_CACHE}"
chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "${VCPKG_DOWNLOADS}" "${VCPKG_BINARY_CACHE}"

# Ensure vcpkg checkout lives on the persistent volume
mkdir -p "${VCPKG_REPO}"
if [ ! -d "${VCPKG_REPO}/.git" ]; then
  echo "[post_create] Cloning vcpkg into ${VCPKG_REPO}..."
  git clone https://github.com/microsoft/vcpkg.git "${VCPKG_REPO}"
else
  echo "[post_create] Updating vcpkg in ${VCPKG_REPO}..."
  git -C "${VCPKG_REPO}" fetch --depth=1 origin main >/dev/null 2>&1 || true
  git -C "${VCPKG_REPO}" reset --hard origin/main >/dev/null 2>&1 || true
fi
if [ ! -x "${VCPKG_REPO}/vcpkg" ]; then
  echo "[post_create] Bootstrapping vcpkg..."
  (cd "${VCPKG_REPO}" && ./bootstrap-vcpkg.sh -disableMetrics)
fi
# Ensure /opt/vcpkg points at the persistent repo and downloads points at the cache
ln -snf "${VCPKG_REPO}" /opt/vcpkg
ln -snf "${VCPKG_DOWNLOADS}" /opt/vcpkg/downloads
chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "${VCPKG_REPO}" /opt/vcpkg
if command -v sudo >/dev/null 2>&1; then
  sudo -n ln -snf /opt/vcpkg/vcpkg /usr/local/bin/vcpkg || true
fi

# Ensure ccache/sccache dirs are owned and writable
mkdir -p "${CCACHE_DIR}" "${SCCACHE_DIR}"
chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "${CCACHE_DIR}" "${SCCACHE_DIR}"

# Make /tmp persistent via symlink into the cache volume if empty
if [ ! -L /tmp ] && [ -z "$(ls -A /tmp)" ]; then
  rm -rf /tmp
  ln -snf "${PERSISTENT_TMP}" /tmp
fi

if ! command -v "clang++-${CLANG_VARIANT}" >/dev/null 2>&1; then
  echo "[post_create] ERROR: clang++-${CLANG_VARIANT} not found in PATH" >&2
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

# CMake configuration is project-specific; skip auto-configure for generic devcontainer
