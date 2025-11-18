#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    echo "Error: must run this script inside the SlotMap repository" >&2
    exit 1
fi

cd "$REPO_ROOT"

LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy_remote_devcontainer_$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Logging to $LOG_FILE"

function usage() {
    cat <<'USAGE'
Usage: deploy_remote_devcontainer.sh <ssh-host> [remote-path] [branch]

Example:
  scripts/deploy_remote_devcontainer.sh c24s1.ch2 ~/dev/github/SlotMap modernization.20251118

The script will:
  1. Push the current local branch to origin.
  2. SSH into the remote host, ensure Docker is running, clone/update the repo, and
     rebuild + restart the devcontainer with the specified branch.
USAGE
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

SSH_HOST="$1"
REMOTE_PATH="${2:-~/dev/github/SlotMap}"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
TARGET_BRANCH="${3:-$CURRENT_BRANCH}"
REMOTE_REPO_URL="https://github.com/rmanaloto-tastytrade/SlotMap.git"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: working tree is dirty. Commit or stash changes before deploying." >&2
    exit 1
fi

echo "Pushing branch ${TARGET_BRANCH} to origin..."
git push origin "${TARGET_BRANCH}"

ssh "${SSH_HOST}" bash <<EOF
set -euo pipefail
REMOTE_PATH="${REMOTE_PATH}"
TARGET_BRANCH="${TARGET_BRANCH}"
REMOTE_REPO_URL="${REMOTE_REPO_URL}"

sudo systemctl enable --now docker
sudo usermod -aG docker "\$USER"

# Ensure repository exists and is up to date
if [[ -d "\$REMOTE_PATH/.git" ]]; then
    cd "\$REMOTE_PATH"
    git fetch origin
else
    mkdir -p "\$(dirname "\$REMOTE_PATH")"
    rm -rf "\$REMOTE_PATH"
    git clone "\$REMOTE_REPO_URL" "\$REMOTE_PATH"
    cd "\$REMOTE_PATH"
fi

git checkout "\$TARGET_BRANCH"
git pull --ff-only origin "\$TARGET_BRANCH"

docker build -f .devcontainer/Dockerfile -t slotmap-dev .
docker rm -f slotmap-dev >/dev/null 2>&1 || true
docker run -d --name slotmap-dev \
  --cap-add=SYS_PTRACE --security-opt=seccomp=unconfined \
  -v "\$REMOTE_PATH:/workspaces/SlotMap" \
  -v slotmap-vcpkg:/opt/vcpkg/downloads \
  -p 9222:9222 slotmap-dev
EOF

echo "Remote devcontainer updated on ${SSH_HOST}:${REMOTE_PATH}".
