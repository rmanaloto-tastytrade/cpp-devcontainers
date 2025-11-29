#!/usr/bin/env bash
set -euo pipefail

# Verify a built devcontainer image and (optionally) SSH into a running devcontainer to check tools.
# - Uses config/env/devcontainer.env by default; override with CONFIG_ENV_FILE.
# - Verifies image presence and runs in-container tool version checks.
# - If a devcontainer is already running and reachable over SSH, performs a quick SSH tool check too.
#
# Usage:
#   CONFIG_ENV_FILE=config/env/devcontainer.env scripts/verify_devcontainer.sh [--image <tag>] [--ssh-port <port>] [--require-ssh]
# Defaults:
#   --image devcontainer:gcc15-clangp2996
#   --ssh-port ${DEVCONTAINER_SSH_PORT:-9222}

REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-"$REPO_ROOT/config/env/devcontainer.env"}"
# shellcheck source=/dev/null
[[ -f "$CONFIG_ENV_FILE" ]] && source "$CONFIG_ENV_FILE"

IMAGE_TAG="devcontainer:gcc15-clangp2996"
SSH_PORT="${DEVCONTAINER_SSH_PORT:-9222}"

REQUIRE_SSH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE_TAG="$2"; shift 2 ;;
    --ssh-port) SSH_PORT="$2"; shift 2 ;;
    --require-ssh) REQUIRE_SSH=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--image <tag>] [--ssh-port <port>] [--require-ssh]
Defaults: --image devcontainer:gcc15-clangp2996, --ssh-port ${SSH_PORT}
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

REMOTE_HOST=${DEVCONTAINER_REMOTE_HOST:?set DEVCONTAINER_REMOTE_HOST}
REMOTE_USER=${DEVCONTAINER_REMOTE_USER:?set DEVCONTAINER_REMOTE_USER}
DOCKER_CONTEXT=${DEVCONTAINER_DOCKER_CONTEXT:-"ssh-${REMOTE_HOST}"}

echo "[verify] Using docker context: ${DOCKER_CONTEXT}"
echo "[verify] Checking image: ${IMAGE_TAG}"

# Ensure image exists on remote
if ! docker --context "${DOCKER_CONTEXT}" image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
  echo "[verify] ERROR: image ${IMAGE_TAG} not found on ${REMOTE_HOST}" >&2
  exit 1
fi

echo "[verify] Running tool checks inside ${IMAGE_TAG}..."
docker --context "${DOCKER_CONTEXT}" run --rm \
  -e PATH="/opt/gcc-15/bin:${PATH}" \
  "${IMAGE_TAG}" \
  bash -lc 'set -e;
    echo "user: $(whoami)";
    echo "clang++-21: $(clang++-21 --version | head -n1)";
    echo "clang++-p2996: $(clang++-p2996 --version | head -n1)";
    echo "gcc-15: $(/opt/gcc-15/bin/gcc-15 --version | head -n1)";
    echo "ninja: $(ninja --version)";
    echo "cmake: $(cmake --version | head -n1)";
    echo "vcpkg: $(vcpkg version | head -n1)";
    echo "mrdocs: $(/opt/mrdocs/bin/mrdocs --version | head -n1)";
  '

# Optional SSH verification against a running devcontainer
echo "[verify] Attempting SSH tool check on ${REMOTE_HOST}:${SSH_PORT} (via ProxyJump)..."
SSH_CMD=(ssh -o StrictHostKeyChecking=accept-new -J "${REMOTE_USER}@${REMOTE_HOST}" -p "${SSH_PORT}" "${REMOTE_USER}@127.0.0.1")
if "${SSH_CMD[@]}" 'set -e; echo "ssh user: $(whoami)"; which clang++-p2996; /opt/gcc-15/bin/gcc-15 --version | head -n1; clang++-p2996 --version | head -n1; ninja --version; cmake --version | head -n1; vcpkg version | head -n1; /opt/mrdocs/bin/mrdocs --version | head -n1' 2>/tmp/verify_ssh_err.log; then
  echo "[verify] SSH tool check succeeded on port ${SSH_PORT}."
else
  echo "[verify] WARNING: SSH tool check failed or container not running. See /tmp/verify_ssh_err.log for details." >&2
  if [[ "${REQUIRE_SSH}" == "1" ]]; then
    exit 1
  fi
fi
