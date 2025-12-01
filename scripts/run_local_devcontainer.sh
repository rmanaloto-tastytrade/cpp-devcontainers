#!/usr/bin/env bash
set -euo pipefail

# This script is meant to be executed directly on the remote Linux host.
# It rebuilds the sandbox workspace and launches the Dev Container via the
# Dev Containers CLI. No git changes occur in the sandbox; it is recreated
# from the clean repo checkout on every run.
#
# Directory layout (defaults can be overridden via environment variables):
#   REPO_PATH    : $HOME/dev/github/SlotMap            (clean git clone)
#   SANDBOX_PATH : $HOME/dev/devcontainers/SlotMap     (recreated each run)
#   KEY_CACHE    : $HOME/.ssh                          (host public keys used for authorized_keys)
#
# Requirements: devcontainer CLI installed on the remote host, Docker running,
# and public key(s) present in $KEY_CACHE (e.g., ~/.ssh/id_ed25519.pub).

# Optional local env overrides
CONFIG_ENV_FILE=${CONFIG_ENV_FILE:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/env/devcontainer.env"}
if [[ -f "$CONFIG_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_ENV_FILE"
fi

# Optional clang branch resolver
CLANG_UTILS_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/clang_branch_utils.sh"
if [[ -f "$CLANG_UTILS_PATH" ]]; then
  # shellcheck source=/dev/null
  source "$CLANG_UTILS_PATH"
  resolve_clang_branch
fi

REPO_PATH=${REPO_PATH:-"$HOME/dev/github/SlotMap"}
SANDBOX_PATH=${SANDBOX_PATH:-"$HOME/dev/devcontainers/SlotMap"}
KEY_CACHE=${KEY_CACHE:-"$HOME/.ssh"}
SSH_SUBDIR=".devcontainer/ssh"
DEV_IMAGE=${DEVCONTAINER_IMAGE:-"cpp-devcontainer:local"}
BASE_IMAGE=${DEVCONTAINER_BASE_IMAGE:-"cpp-dev-base:local"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_USER=${CONTAINER_USER:-$(id -un)}
CONTAINER_UID=${CONTAINER_UID:-$(id -u)}
CONTAINER_GID=${CONTAINER_GID:-$(id -g)}
DEVCONTAINER_CLI_VERSION=${DEVCONTAINER_CLI_VERSION:-"0.80.2"}
DOCKER_CONTEXT=${DOCKER_CONTEXT:-}
WORKSPACE_PATH=${WORKSPACE_PATH:-"/home/${CONTAINER_USER}/dev/devcontainers/workspace"}
DEVCONTAINER_SSH_PORT=${DEVCONTAINER_SSH_PORT:-9222}
DEVCONTAINER_SKIP_BAKE=${DEVCONTAINER_SKIP_BAKE:-0}
DEVCONTAINER_VERIFY=${DEVCONTAINER_VERIFY:-0}

echo "[remote] Repo source       : $REPO_PATH"
echo "[remote] Sandbox workspace : $SANDBOX_PATH"
echo "[remote] Host key cache    : $KEY_CACHE"
echo "[remote] Workspace mount   : $WORKSPACE_PATH"
echo

if [[ -n "$DOCKER_CONTEXT" ]]; then
  echo "[remote] Using docker context: $DOCKER_CONTEXT"
  export DOCKER_CONTEXT
fi

ensure_devcontainer_cli() {
  if command -v devcontainer >/dev/null 2>&1; then
    local current
    current="$(devcontainer --version 2>/dev/null || true)"
    if [[ "$current" == "$DEVCONTAINER_CLI_VERSION" ]]; then
      echo "[remote] Found devcontainer CLI $current."
      return 0
    fi
    echo "[remote] devcontainer CLI version $current != $DEVCONTAINER_CLI_VERSION; upgrading..."
  else
    echo "[remote] devcontainer CLI not found; installing $DEVCONTAINER_CLI_VERSION..."
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "[remote] ERROR: npm is required to install @devcontainers/cli. Install Node.js/npm on the host and rerun." >&2
    exit 1
  fi

  npm install -g "@devcontainers/cli@${DEVCONTAINER_CLI_VERSION}"
  if devcontainer --version >/dev/null 2>&1; then
    local post_install
    post_install="$(devcontainer --version 2>/dev/null || true)"
    if [[ "$post_install" == "$DEVCONTAINER_CLI_VERSION" ]]; then
      echo "[remote] Installed devcontainer CLI $post_install."
    else
      echo "[remote] ERROR: devcontainer CLI still reports $post_install after install; check PATH/symlink to the new npm global bin." >&2
      exit 1
    fi
  else
    echo "[remote] ERROR: devcontainer CLI installation failed." >&2
    exit 1
  fi
}

[[ -d "$REPO_PATH" ]] || { echo "[remote] ERROR: Repo path not found."; exit 1; }
if [[ -z "${SSH_AUTH_SOCK:-}" || ! -S "${SSH_AUTH_SOCK:-}" ]]; then
  echo "[remote] SSH_AUTH_SOCK not set; starting a fresh ssh-agent..."
  eval "$(ssh-agent -s)"
  DEFAULT_HOST_KEY="${HOST_SSH_KEY_PATH:-$HOME/.ssh/github_key}"
  if [[ -f "$DEFAULT_HOST_KEY" ]]; then
    if ssh-add "$DEFAULT_HOST_KEY" >/dev/null 2>&1; then
      echo "[remote] Added key $DEFAULT_HOST_KEY to agent."
    else
      echo "[remote] WARNING: Failed to add $DEFAULT_HOST_KEY to agent (maybe passphrase-protected)." >&2
    fi
  else
    echo "[remote] WARNING: No host key found at $DEFAULT_HOST_KEY to add to agent." >&2
  fi
fi

[[ -d "$KEY_CACHE" ]] || { echo "[remote] WARNING: Key cache $KEY_CACHE missing; creating it."; mkdir -p "$KEY_CACHE"; }

echo "[remote] Removing previous sandbox..."
rm -rf "$SANDBOX_PATH"
mkdir -p "$SANDBOX_PATH"
mkdir -p "$WORKSPACE_PATH"

echo "[remote] Copying repo into sandbox..."
rsync -a --delete "$REPO_PATH"/ "$SANDBOX_PATH"/
if [[ "$WORKSPACE_PATH" != "$SANDBOX_PATH" ]]; then
  echo "[remote] Copying repo into workspace source..."
  rsync -a --delete "$REPO_PATH"/ "$WORKSPACE_PATH"/
fi

update_devcontainer_image() {
  local target_path="$1/.devcontainer/devcontainer.json"
  if [[ -f "$target_path" && -n "$DEV_IMAGE" ]]; then
    if command -v jq >/dev/null 2>&1; then
      local tmp
      tmp="$(mktemp)"
      jq --arg image "$DEV_IMAGE" --arg user "$CONTAINER_USER" \
        '.image=$image | .remoteUser=$user' "$target_path" >"$tmp" && mv "$tmp" "$target_path"
    else
      echo "[remote] WARNING: jq not available; leaving ${target_path} unchanged." >&2
    fi
  fi
}

update_devcontainer_image "$SANDBOX_PATH"
if [[ "$WORKSPACE_PATH" != "$SANDBOX_PATH" ]]; then
  update_devcontainer_image "$WORKSPACE_PATH"
fi

SSH_TARGET="$SANDBOX_PATH/$SSH_SUBDIR"
mkdir -p "$SSH_TARGET"

if compgen -G "$KEY_CACHE/*.pub" > /dev/null; then
  echo "[remote] Staging SSH public keys for container authorized_keys:"
  for pub in "$KEY_CACHE"/*.pub; do
    base=$(basename "$pub")
    echo "  -> $pub"
    cp "$pub" "$SSH_TARGET/$base"
  done
else
  echo "[remote] WARNING: No *.pub files found in $KEY_CACHE; container SSH access may fail. Add public keys to $KEY_CACHE if needed."
fi

if [[ "$WORKSPACE_PATH" != "$SANDBOX_PATH" ]]; then
  WORKSPACE_SSH_TARGET="$WORKSPACE_PATH/$SSH_SUBDIR"
  mkdir -p "$WORKSPACE_SSH_TARGET"
  rsync -a --delete "$SSH_TARGET"/ "$WORKSPACE_SSH_TARGET"/
fi

echo "[remote] Ensuring baked images (base: $BASE_IMAGE, dev: $DEV_IMAGE)..."
pushd "$SANDBOX_PATH" >/dev/null
# Validate bake/devcontainer config unless skipping bake
if [[ "$DEVCONTAINER_SKIP_BAKE" != "1" ]]; then
  "$SCRIPT_DIR/check_docker_bake.sh" "$SANDBOX_PATH"
  ensure_devcontainer_cli
  "$SCRIPT_DIR/check_devcontainer_config.sh" "$SANDBOX_PATH"
  # Build base if missing
  if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
    echo "[remote] Base image $BASE_IMAGE missing; baking base..."
    docker buildx bake \
      -f "$SANDBOX_PATH/.devcontainer/docker-bake.hcl" \
      base \
      --set base.tags="$BASE_IMAGE" \
      --set '*.args.BASE_IMAGE'="$BASE_IMAGE" \
      --set '*.args.USERNAME'="$CONTAINER_USER" \
      --set '*.args.USER_UID'="$CONTAINER_UID" \
      --set '*.args.USER_GID'="$CONTAINER_GID"
  else
    echo "[remote] Found base image $BASE_IMAGE."
  fi

  # Rebuild devcontainer with current user/uid/gid
  echo "[remote] Baking devcontainer image (user=${CONTAINER_USER}, uid=${CONTAINER_UID}, gid=${CONTAINER_GID})..."
  docker buildx bake \
    -f "$SANDBOX_PATH/.devcontainer/docker-bake.hcl" \
    devcontainer \
    --set base.tags="$BASE_IMAGE" \
    --set devcontainer.tags="$DEV_IMAGE" \
    --set '*.args.BASE_IMAGE'="$BASE_IMAGE" \
    --set '*.args.USERNAME'="$CONTAINER_USER" \
    --set '*.args.USER_UID'="$CONTAINER_UID" \
    --set '*.args.USER_GID'="$CONTAINER_GID"
else
  echo "[remote] DEVCONTAINER_SKIP_BAKE=1; skipping bake and using image ${DEV_IMAGE}."
fi
popd >/dev/null

export DEVCONTAINER_USER="${CONTAINER_USER}"
export DEVCONTAINER_UID="${CONTAINER_UID}"
export DEVCONTAINER_GID="${CONTAINER_GID}"
export DEVCONTAINER_WORKSPACE_PATH="${WORKSPACE_PATH}"
export REMOTE_WORKSPACE_PATH="${WORKSPACE_PATH}"
export REMOTE_SSH_SYNC_DIR="${KEY_CACHE}"
export DEVCONTAINER_SSH_PORT="${DEVCONTAINER_SSH_PORT}"
export DEVCONTAINER_IMAGE="${DEV_IMAGE}"

echo "[remote] Building container user ${CONTAINER_USER} (uid=${CONTAINER_UID}, gid=${CONTAINER_GID})"

echo "[remote] Running devcontainer up..."
devcontainer up \
  --workspace-folder "$SANDBOX_PATH" \
  --remove-existing-container \
  --build-no-cache

CONTAINER_ID=$(docker ps --filter "label=devcontainer.local_folder=${SANDBOX_PATH}" -q | head -n1)
if [[ -n "$CONTAINER_ID" ]]; then
  echo "[remote] Container $CONTAINER_ID online. Inspecting filesystem (sanity check)..."
docker exec "$CONTAINER_ID" sh -c 'echo "--- /tmp ---"; ls -al /tmp | head'
docker exec "$CONTAINER_ID" sh -c 'echo "--- workspace (top level) ---"; ls -al "$HOME/workspace" | head'
docker exec "$CONTAINER_ID" sh -c 'echo "--- LLVM packages list ---"; if [ -f /opt/llvm-packages-21.txt ]; then head /opt/llvm-packages-21.txt; else echo "No /opt/llvm-packages-21.txt"; fi'
  echo "[remote] docker ps (filtered for this devcontainer):"
  docker ps --filter "label=devcontainer.local_folder=${SANDBOX_PATH}" --format 'table {{.ID}}\t{{.Status}}\t{{.Ports}}'
  echo "[remote] sshd inside container:"
  docker exec "$CONTAINER_ID" sh -c 'ps -ef | grep "[s]shd" || true'
  # SSH connectivity check if a private key is available
  SSH_TEST_KEY="${KEY_CACHE}/id_ed25519"
  if [[ -f "$SSH_TEST_KEY" ]]; then
    echo "[remote] Testing SSH into container on port ${DEVCONTAINER_SSH_PORT}..."
    if ssh -i "$SSH_TEST_KEY" -o StrictHostKeyChecking=no -o BatchMode=yes -p "${DEVCONTAINER_SSH_PORT}" "${CONTAINER_USER}@localhost" exit >/dev/null 2>&1; then
      echo "[remote] SSH test succeeded using ${SSH_TEST_KEY}."
    else
      echo "[remote] WARNING: SSH test failed using ${SSH_TEST_KEY}. Check authorized_keys and port mapping."
    fi
  else
    echo "[remote] WARNING: No ${SSH_TEST_KEY} found for SSH test."
  fi
  if [[ "$DEVCONTAINER_VERIFY" == "1" ]]; then
    echo "[remote] Running post-up verification (image ${DEV_IMAGE}, port ${DEVCONTAINER_SSH_PORT})..."
    "${SANDBOX_PATH}/scripts/verify_devcontainer.sh" --image "${DEV_IMAGE}" --ssh-port "${DEVCONTAINER_SSH_PORT}" --require-ssh
  fi
else
  echo "[remote] WARNING: unable to locate container for inspection."
fi

echo "[remote] Devcontainer ready. Workspace: $SANDBOX_PATH"
