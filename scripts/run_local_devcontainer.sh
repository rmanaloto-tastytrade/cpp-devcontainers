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
#   KEY_CACHE    : $HOME/macbook_ssh_keys              (rsynced from your Mac)
#
# Requirements: devcontainer CLI installed on the remote host, Docker running,
# and your public key(s) copied into $KEY_CACHE (e.g., ~/.ssh/id_ed25519.pub).

REPO_PATH=${REPO_PATH:-"$HOME/dev/github/SlotMap"}
SANDBOX_PATH=${SANDBOX_PATH:-"$HOME/dev/devcontainers/SlotMap"}
KEY_CACHE=${KEY_CACHE:-"$HOME/macbook_ssh_keys"}
SSH_SUBDIR=".devcontainer/ssh"

echo "[remote] Repo source       : $REPO_PATH"
echo "[remote] Sandbox workspace : $SANDBOX_PATH"
echo "[remote] Mac key cache     : $KEY_CACHE"
echo

[[ -d "$REPO_PATH" ]] || { echo "[remote] ERROR: Repo path not found."; exit 1; }
[[ -d "$KEY_CACHE" ]] || { echo "[remote] WARNING: Key cache $KEY_CACHE missing; create and rsync your .pub keys there."; mkdir -p "$KEY_CACHE"; }

echo "[remote] Removing previous sandbox..."
rm -rf "$SANDBOX_PATH"
mkdir -p "$SANDBOX_PATH"

echo "[remote] Copying repo into sandbox..."
rsync -a --delete "$REPO_PATH"/ "$SANDBOX_PATH"/

SSH_TARGET="$SANDBOX_PATH/$SSH_SUBDIR"
mkdir -p "$SSH_TARGET"

if compgen -G "$KEY_CACHE/*.pub" > /dev/null; then
  echo "[remote] Staging SSH keys:"
  for pub in "$KEY_CACHE"/*.pub; do
    base=$(basename "$pub")
    echo "  -> $pub"
    cp "$pub" "$SSH_TARGET/$base"
  done
else
  echo "[remote] ERROR: No *.pub files found in $KEY_CACHE."
  echo "         Copy your public key to $KEY_CACHE before rerunning."
  exit 1
fi

CONTAINER_USER=${CONTAINER_USER:-$(id -un)}
CONTAINER_UID=${CONTAINER_UID:-$(id -u)}
CONTAINER_GID=${CONTAINER_GID:-$(id -g)}

export DEVCONTAINER_USER="${CONTAINER_USER}"
export DEVCONTAINER_UID="${CONTAINER_UID}"
export DEVCONTAINER_GID="${CONTAINER_GID}"

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
docker exec "$CONTAINER_ID" sh -c 'echo "--- /workspaces/SlotMap (top level) ---"; ls -al /workspaces/SlotMap | head'
docker exec "$CONTAINER_ID" sh -c 'echo "--- LLVM packages list ---"; if [ -f /opt/llvm-packages-21.txt ]; then head /opt/llvm-packages-21.txt; else echo "No /opt/llvm-packages-21.txt"; fi'
else
  echo "[remote] WARNING: unable to locate container for inspection."
fi

echo "[remote] Devcontainer ready. Workspace: $SANDBOX_PATH"
