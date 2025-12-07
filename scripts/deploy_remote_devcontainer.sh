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
  --remote-host <host>       Remote SSH host (required if no DEFAULT_REMOTE_HOST env)
  --remote-user <user>       Remote SSH user (default: current user)
  --ssh-key <path>           Local public key to copy (default: ~/.ssh/id_ed25519.pub)
  --remote-key-cache <path>  Remote key cache dir (default: ~/macbook_ssh_keys)
  --remote-repo <path>       Remote repo path (default: ~/dev/github/SlotMap)
  --remote-sandbox <path>    Remote sandbox path (default: ~/dev/devcontainers/cpp-devcontainer)
  --docker-context <name>    Docker SSH context to use/create (optional)
  --ssh-sync-source <path>   Local ssh dir to sync (default: ~/.ssh/) [deprecated; default sync disabled]
  --remote-ssh-sync-dir <path> Remote dir to receive synced ssh keys (default: ~/devcontainers/ssh_keys) [deprecated]
  --sync-mac-ssh <0|1>       Enable/disable syncing local ssh dir (default: 0)
  --remote-workspace <path>  Remote host path to bind as workspace in the container (default: /home/<CONTAINER_USER>/dev/devcontainers/workspace)
  -h, --help                 Show this help
USAGE
}

die(){ echo "Error: $*" >&2; exit 1; }

LOCAL_USER="$(id -un)"
DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-""}"
REMOTE_HOST=""
REMOTE_USER=""
SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
PRIVATE_KEY_PATH=""
REMOTE_PORT=""
REMOTE_KEY_CACHE=""
REMOTE_REPO_PATH=""
REMOTE_SANDBOX_PATH=""
REMOTE_SSH_SYNC_DIR="${REMOTE_SSH_SYNC_DIR:-""}"
SSH_SYNC_SOURCE="${SSH_SYNC_SOURCE:-"$HOME/.ssh/"}"
SYNC_MAC_SSH="${SYNC_MAC_SSH:-0}"
DOCKER_CONTEXT="${DOCKER_CONTEXT:-}"
RSYNC_SSH="${RSYNC_SSH:-ssh -o StrictHostKeyChecking=accept-new}"
# Container identity defaults: set after REMOTE_USER resolves
CONTAINER_USER="${CONTAINER_USER:-}"
CONTAINER_UID="${CONTAINER_UID:-}"
CONTAINER_GID="${CONTAINER_GID:-}"
REMOTE_WORKSPACE_PATH="${REMOTE_WORKSPACE_PATH:-""}"

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
    --docker-context)
      DOCKER_CONTEXT="$2"; shift 2 ;;
    --remote-workspace)
      REMOTE_WORKSPACE_PATH="$2"; shift 2 ;;
    --remote-port)
      REMOTE_PORT="$2"; shift 2 ;;
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
# Optional local env overrides
CONFIG_ENV_FILE=${CONFIG_ENV_FILE:-"$REPO_ROOT/config/env/devcontainer.env"}
if [[ -f "$CONFIG_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_ENV_FILE"
fi
cd "$REPO_ROOT"
# Track branch info for remote rebuild scripts; fallback to commit hash if detached
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || git rev-parse HEAD 2>/dev/null || echo "unknown")"

# Apply defaults after loading config/env/devcontainer.env (if present)
REMOTE_HOST=${REMOTE_HOST:-${DEVCONTAINER_REMOTE_HOST:-${DEFAULT_REMOTE_HOST:-""}}}
REMOTE_USER=${REMOTE_USER:-${DEVCONTAINER_REMOTE_USER:-""}}
REMOTE_PORT=${REMOTE_PORT:-${DEVCONTAINER_SSH_PORT:-9222}}
DOCKER_CONTEXT=${DOCKER_CONTEXT:-${DEVCONTAINER_DOCKER_CONTEXT:-""}}
SSH_SYNC_SOURCE=${SSH_SYNC_SOURCE:-"$HOME/.ssh/"}
REMOTE_SSH_SYNC_DIR=${REMOTE_SSH_SYNC_DIR:-""}

CONFIG_REMOTE_USER="$(git config --get cppdev.remoteUser || true)"
if [[ -z "$REMOTE_USER" ]]; then
  if [[ -n "$CONFIG_REMOTE_USER" ]]; then
    REMOTE_USER="$CONFIG_REMOTE_USER"
  elif [[ "$LOCAL_USER" == *"@"* ]]; then
    die "Remote user is required (pass --remote-user or run 'git config cppdev.remoteUser <username>')"
  else
    REMOTE_USER="$LOCAL_USER"
  fi
fi

# Fix: Respect SSH key from config file if not overridden by flag
if [[ -n "${DEVCONTAINER_SSH_KEY:-}" ]]; then
  # Only update if it's currently the default and not manually set via flag
  # (Simplification: We assume if DEVCONTAINER_SSH_KEY is set, we want to use it unless user passed --ssh-key.
  #  However, checking if user passed flag is hard here without extra vars. 
  #  Standard priority: Flag > Env > Default.
  #  Since SSH_KEY_PATH is initialized to default, simply overwriting it here works as "Env > Default".
  #  BUT if user passed --ssh-key, SSH_KEY_PATH is already set to that. We shouldn't clobber it with Env.
  #  We can check if SSH_KEY_PATH equals default "id_ed25519.pub". If so, safe to update.)
   if [[ "$SSH_KEY_PATH" == "$HOME/.ssh/id_ed25519.pub" ]]; then
      SSH_KEY_PATH="${DEVCONTAINER_SSH_KEY}"
   fi
fi

# Preserve private key path for later SSH tests before we coerce to .pub
PRIVATE_KEY_PATH="${SSH_KEY_PATH}"
if [[ "$PRIVATE_KEY_PATH" == *.pub ]]; then
  PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH%.pub}"
fi

# Fix: Ensure we are using the public key for copying
if [[ "$SSH_KEY_PATH" != *.pub ]]; then
  if [[ -f "${SSH_KEY_PATH}.pub" ]]; then
    echo "[script] Resolving public key for deployment: ${SSH_KEY_PATH} -> ${SSH_KEY_PATH}.pub"
    SSH_KEY_PATH="${SSH_KEY_PATH}.pub"
  fi
fi

if [[ -z "$REMOTE_HOST" ]]; then
  die "Remote host is required (set DEVCONTAINER_REMOTE_HOST/DEFAULT_REMOTE_HOST or pass --remote-host)"
fi

CONTAINER_USER=${CONTAINER_USER:-$REMOTE_USER}

REMOTE_HOME=${REMOTE_HOME:-"/home/${REMOTE_USER}"}
REMOTE_KEY_CACHE=${REMOTE_KEY_CACHE:-"${REMOTE_HOME}/devcontainers/ssh_keys"}
REMOTE_REPO_PATH=${REMOTE_REPO_PATH:-"${REMOTE_HOME}/dev/github/SlotMap"}
REMOTE_SANDBOX_PATH=${REMOTE_SANDBOX_PATH:-${SANDBOX_PATH:-"${REMOTE_HOME}/dev/devcontainers/cpp-devcontainer"}}
REMOTE_SSH_SYNC_DIR=${REMOTE_SSH_SYNC_DIR:-"${REMOTE_HOME}/devcontainers/ssh_keys"}
REMOTE_WORKSPACE_PATH=${REMOTE_WORKSPACE_PATH:-${WORKSPACE_PATH:-"${REMOTE_HOME}/dev/devcontainers/workspace"}}
DEVCONTAINER_SKIP_GIT_SYNC=${DEVCONTAINER_SKIP_GIT_SYNC:-0}
# Where the public key will be staged on the remote host
REMOTE_KEY_PATH="${REMOTE_KEY_CACHE%/}/$(basename "$SSH_KEY_PATH")"

ensure_docker_context() {
  if [[ -z "$DOCKER_CONTEXT" ]]; then
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    if ! docker context inspect "$DOCKER_CONTEXT" >/dev/null 2>&1; then
      echo "Creating docker context '$DOCKER_CONTEXT' for $REMOTE_USER@$REMOTE_HOST..."
      docker context create "$DOCKER_CONTEXT" --docker "host=ssh://${REMOTE_USER}@${REMOTE_HOST}"
    else
      echo "Using existing docker context '$DOCKER_CONTEXT'."
    fi
  else
    echo "WARNING: docker CLI not available locally; cannot create/verify docker context '$DOCKER_CONTEXT'."
  fi
}

if [[ "${SYNC_MAC_SSH}" == "1" ]]; then
  echo "Syncing local SSH directory to remote: ${SSH_SYNC_SOURCE} -> ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SSH_SYNC_DIR}"
  rsync -e "${RSYNC_SSH}" -av --chmod=F600,D700 --rsync-path="mkdir -p ${REMOTE_SSH_SYNC_DIR} && rsync" \
    "${SSH_SYNC_SOURCE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SSH_SYNC_DIR}/"
else
  echo "Skipping SSH sync (SYNC_MAC_SSH=${SYNC_MAC_SSH})."
fi

# Resolve remote uid/gid for the container user (unless explicitly forced)
if [[ "${DEVCONTAINER_FORCE_UID:-0}" != "1" ]]; then
  REMOTE_UID=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "id -u ${CONTAINER_USER}" 2>/dev/null || true)
  REMOTE_GID=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "id -g ${CONTAINER_USER}" 2>/dev/null || true)
  if [[ -n "$REMOTE_UID" && -n "$REMOTE_GID" ]]; then
    CONTAINER_UID="$REMOTE_UID"
    CONTAINER_GID="$REMOTE_GID"
  else
    echo "WARNING: Could not resolve uid/gid for ${CONTAINER_USER} on ${REMOTE_HOST}; falling back to local uid/gid."
    CONTAINER_UID="${CONTAINER_UID:-$(id -u)}"
    CONTAINER_GID="${CONTAINER_GID:-$(id -g)}"
  fi
fi

LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy_remote_devcontainer_$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Removed dirty tree check to allow rsync deployment of uncommitted changes
# [[ -n "$(git status --porcelain)" ]] && die "working tree is dirty"

ensure_docker_context

echo "Copying key to remote cache: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_KEY_PATH}"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p $REMOTE_KEY_CACHE"
scp "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_KEY_PATH}"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "chmod 700 $REMOTE_KEY_CACHE && chmod 600 $REMOTE_KEY_PATH"

# Optimization: Use rsync to mirror local "dirty" tree to remote, bypassing git push/pull latency and restrictions
echo "Syncing local repository to remote: $REPO_ROOT -> ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_REPO_PATH}"
# Create remote parent dir
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p \"${REMOTE_REPO_PATH}\""
# Rsync the content (including .git so versioning works, but delete extraneous files)
rsync -e "${RSYNC_SSH}" -az --delete \
  --exclude '.build/' --exclude 'build/' --exclude 'cmake-build-*/' \
  "$REPO_ROOT/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_REPO_PATH}/"

echo "Triggering remote devcontainer rebuild..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" \
  REPO_PATH="$REMOTE_REPO_PATH" \
  SANDBOX_PATH="$REMOTE_SANDBOX_PATH" \
  KEY_CACHE="$REMOTE_KEY_CACHE" \
  BRANCH="$CURRENT_BRANCH" \
  CONTAINER_USER="$CONTAINER_USER" \
  CONTAINER_UID="$CONTAINER_UID" \
  CONTAINER_GID="$CONTAINER_GID" \
  WORKSPACE_PATH="$REMOTE_WORKSPACE_PATH" \
  DEVCONTAINER_SSH_PORT="$REMOTE_PORT" \
  DEVCONTAINER_SKIP_GIT_SYNC="$DEVCONTAINER_SKIP_GIT_SYNC" \
  CLANG_VARIANT="${CLANG_VARIANT:-}" \
  GCC_VERSION="${GCC_VERSION:-}" \
  REQUIRE_P2996="${REQUIRE_P2996:-0}" \
  ENABLE_CLANG_P2996="${ENABLE_CLANG_P2996:-0}" \
  ENABLE_GCC15="${ENABLE_GCC15:-0}" \
  DEVCONTAINER_IMAGE="${DEVCONTAINER_IMAGE:-}" \
  bash <<'EOF'
set -euo pipefail
# Repo is already updated via rsync; skipping git operations
cd "$REPO_PATH"
REPO_PATH="$REPO_PATH" \
SANDBOX_PATH="$SANDBOX_PATH" \
KEY_CACHE="$KEY_CACHE" \
DEVCONTAINER_SSH_PORT="$DEVCONTAINER_SSH_PORT" \
DEVCONTAINER_SKIP_GIT_SYNC="$DEVCONTAINER_SKIP_GIT_SYNC" \
CLANG_VARIANT="${CLANG_VARIANT:-}" \
GCC_VERSION="${GCC_VERSION:-}" \
REQUIRE_P2996="${REQUIRE_P2996:-0}" \
ENABLE_CLANG_P2996="${ENABLE_CLANG_P2996:-0}" \
ENABLE_GCC15="${ENABLE_GCC15:-0}" \
DEVCONTAINER_IMAGE="${DEVCONTAINER_IMAGE:-}" \
./scripts/run_local_devcontainer.sh
EOF

echo "Remote devcontainer rebuilt via scripts/run_local_devcontainer.sh on ${REMOTE_HOST}."
echo "Running post-deploy SSH connectivity test from local host..."
"${REPO_ROOT}/scripts/test_devcontainer_ssh.sh" \
  --host "${REMOTE_HOST}" \
  --port "${REMOTE_PORT}" \
  --user "${CONTAINER_USER}" \
  --key "${PRIVATE_KEY_PATH}" \
  --clear-known-host
