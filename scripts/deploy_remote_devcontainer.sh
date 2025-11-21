#!/usr/bin/env bash
set -euo pipefail

# This script runs from your local machine (e.g., your Mac).
# It ensures your git branch is pushed, copies your public key to the remote host,
# and then triggers scripts/run_local_devcontainer.sh on the remote host to rebuild the
# sandbox devcontainer workspace.

usage() {
  cat <<'USAGE'
Usage: scripts/deploy_remote_devcontainer.sh [options]

Options:
  --remote-host <host>       Remote SSH host (default: c24s1.ch2)
  --remote-user <user>       Remote SSH user (default: current user)
  --ssh-key <path>           Local public key to copy (default: ~/.ssh/id_ed25519.pub)
  --remote-key-cache <path>  Remote key cache dir (default: ~/macbook_ssh_keys)
  --remote-repo <path>       Remote repo path (default: ~/dev/github/SlotMap)
  --remote-sandbox <path>    Remote sandbox path (default: ~/dev/devcontainers/SlotMap)
  -h, --help                 Show this help
USAGE
}

die(){ echo "Error: $*" >&2; exit 1; }

LOCAL_USER="$(id -un)"
REMOTE_HOST="c24s1.ch2"
REMOTE_USER="rmanaloto"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
REMOTE_KEY_CACHE="$HOME/macbook_ssh_keys"
REMOTE_REPO_PATH="$HOME/dev/github/SlotMap"
REMOTE_SANDBOX_PATH="$HOME/dev/devcontainers/SlotMap"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-key)
      SSH_KEY_PATH="$2"; shift 2 ;;
    --remote-key-cache)
      REMOTE_KEY_CACHE="$2"; shift 2 ;;
    --remote-repo)
      REMOTE_REPO_PATH="$2"; shift 2 ;;
    --remote-sandbox)
      REMOTE_SANDBOX_PATH="$2"; shift 2 ;;
    --remote-host)
      REMOTE_HOST="$2"; shift 2 ;;
    --remote-user)
      REMOTE_USER="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    --)
      shift; break ;;
    -*)
      echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)
      echo "Unexpected argument: $1" >&2; usage; exit 1 ;;
  esac
done

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

CONFIG_REMOTE_USER="$(git config --get slotmap.remoteUser || true)"
if [[ -z "$REMOTE_USER" ]]; then
  if [[ -n "$CONFIG_REMOTE_USER" ]]; then
    REMOTE_USER="$CONFIG_REMOTE_USER"
  elif [[ "$LOCAL_USER" == *"@"* ]]; then
    die "Remote user is required (pass --remote-user or run 'git config slotmap.remoteUser <username>')"
  else
    REMOTE_USER="$LOCAL_USER"
  fi
fi

LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy_remote_devcontainer_$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

[[ -n "$(git status --porcelain)" ]] && die "working tree is dirty"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Pushing branch ${CURRENT_BRANCH} to origin..."
git push origin "$CURRENT_BRANCH"

[[ -f "$SSH_KEY_PATH" ]] || die "SSH key not found: $SSH_KEY_PATH"
KEY_FILENAME="$(basename "$SSH_KEY_PATH")"
REMOTE_KEY_PATH="${REMOTE_KEY_CACHE}/${KEY_FILENAME}"

echo "Copying key to remote cache: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_KEY_PATH}"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p $REMOTE_KEY_CACHE"
scp "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_KEY_PATH}"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "chmod 700 $REMOTE_KEY_CACHE && chmod 600 $REMOTE_KEY_PATH"

echo "Triggering remote devcontainer rebuild..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" \
  REPO_PATH="$REMOTE_REPO_PATH" \
  SANDBOX_PATH="$REMOTE_SANDBOX_PATH" \
  KEY_CACHE="$REMOTE_KEY_CACHE" \
  BRANCH="$CURRENT_BRANCH" \
  bash <<'EOF'
set -euo pipefail
cd "$REPO_PATH"
git fetch origin
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"
REPO_PATH="$REPO_PATH" \
SANDBOX_PATH="$SANDBOX_PATH" \
KEY_CACHE="$KEY_CACHE" \
./scripts/run_local_devcontainer.sh
EOF

echo "Remote devcontainer rebuilt via scripts/run_local_devcontainer.sh on ${REMOTE_HOST}."
