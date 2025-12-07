#!/usr/bin/env bash
set -euo pipefail

# verify_remote_devcontainer_matrix.sh
#
# Fully automated verification script for the SlotMap devcontainer matrix.
# 1. Iterates through all 6 permutations (gcc14/15 x clang21/22/p2996).
# 2. Performs a SAFE, hard cleanup on the remote host before each build.
# 3. Deploys the configuration.
# 4. Verifies SSH connectivity.
# 5. Generates a summary report.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT_DIR}/logs/matrix_$(date +%Y%m%d_%H%M%S)"
SUMMARY_FILE="${LOG_DIR}/summary_report.md"

mkdir -p "$LOG_DIR"

# Matrix Definitions
CONFIGS=(
  "gcc14-clang21"
  "gcc14-clang22"
  "gcc14-clangp2996"
  "gcc15-clang21"
  "gcc15-clang22"
  "gcc15-clangp2996"
)

# Host Configuration: set HOST_ENV_PREFIX (e.g., devcontainer.<host>) or leave blank for auto-detect
HOST_ENV_PREFIX="${HOST_ENV_PREFIX:-}"

resolve_env_file() {
  local conf="$1"
  if [[ -n "$HOST_ENV_PREFIX" ]]; then
    echo "${ROOT_DIR}/config/env/${HOST_ENV_PREFIX}.${conf}.env"
  else
    ls -1 "${ROOT_DIR}"/config/env/devcontainer.*.${conf}.env 2>/dev/null | head -n 1 || true
  fi
}

log() {
  echo "[$(date +'%T')] $*" | tee -a "${LOG_DIR}/main.log"
}

report() {
  echo "$*" >> "$SUMMARY_FILE"
}

cleanup_remote() {
  local remote_user="$1"
  local remote_host="$2"
  
  log "🧹 Cleaning up project artifacts on ${remote_host}..."
  
  # Targeted cleanup commands
  local cmds="
    set -e
    # 1. Stop/Remove project containers (labelled for cppdev sandboxes)
    docker ps -a --format '{{.ID}} {{.Label \"devcontainer.local_folder\"}}' | awk '/devcontainers\\/cppdev/ {print \$1}' | xargs -r docker rm -f
    
    # 2. Remove project images
    docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^(vsc-cppdev|cpp-devcontainer|cpp-dev-base)' | xargs -r docker rmi -f
    
    # 3. Remove project cache volume (Hard Reset)
    docker volume rm cppdev-cache || true
    
    # 4. Clean build metadata
    rm -rf ~/dev/devcontainers/build_meta/*
  "
  
  if ssh "${remote_user}@${remote_host}" "/bin/bash -s" <<< "$cmds"; then
    log "✅ Remote cleanup successful."
  else
    log "⚠️  Remote cleanup had issues (check main log)."
  fi
}

ensure_perm_clear() {
  local remote_user="$1"
  local remote_host="$2"
  local port="$3"
  local sandbox="$4"
  local clear_cmd="
    set -e
    docker ps -q --filter publish=${port}/tcp | xargs -r docker rm -f
    docker ps -q --filter publish=127.0.0.1:${port} | xargs -r docker rm -f
    if [[ -n \"${sandbox}\" ]]; then
      docker ps -q --filter \"label=devcontainer.local_folder=${sandbox}\" | xargs -r docker rm -f
    fi
  "
  ssh "${remote_user}@${remote_host}" "/bin/bash -s" <<< "$clear_cmd" >> "${LOG_DIR}/main.log" 2>&1 || true
}

# Initialize Report
echo "# Devcontainer Matrix Verification Report" > "$SUMMARY_FILE"
echo "Date: $(date)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "| Config | Deploy | SSH check | Status |" >> "$SUMMARY_FILE"
echo "|---|---|---|---|" >> "$SUMMARY_FILE"

log "🚀 Starting Matrix Verification. Logs: ${LOG_DIR}"

# Enforce clean working tree unless explicitly allowed
if [[ "${DEVCONTAINER_ALLOW_DIRTY:-0}" != "1" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    log "❌ Local git tree is dirty. Set DEVCONTAINER_ALLOW_DIRTY=1 to override."
    exit 1
  fi
fi

# Single pre-run cleanup (avoid deleting containers between permutations)
for conf in "${CONFIGS[@]}"; do
  ENV_FILE="$(resolve_env_file "${conf}")"
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
    R_USER="${DEVCONTAINER_REMOTE_USER:-}"
    R_HOST="${DEVCONTAINER_REMOTE_HOST:-}"
    if [[ -n "$R_USER" && -n "$R_HOST" ]]; then
      cleanup_remote "$R_USER" "$R_HOST" >> "${LOG_DIR}/main.log" 2>&1
      break
    fi
  fi
done

for conf in "${CONFIGS[@]}"; do
  ENV_FILE="$(resolve_env_file "${conf}")"
  PERM_LOG="${LOG_DIR}/${conf}.log"
  
  log "---------------------------------------------------"
  log "Testing Permutation: ${conf}"
  [[ -n "$ENV_FILE" ]] && log "Using env file: ${ENV_FILE}"
  
  if [[ ! -f "$ENV_FILE" ]]; then
    log "❌ Config verify failed: ${ENV_FILE} missing."
    report "| ${conf} | ❌ Missing | ⚪ | **SKIPPED** |"
    continue
  fi
  # Load env for this permutation (exported)
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
  R_USER="${DEVCONTAINER_REMOTE_USER:-}"
  R_HOST="${DEVCONTAINER_REMOTE_HOST:-}"
  R_PORT="${DEVCONTAINER_SSH_PORT:-9222}"
  R_KEY="${DEVCONTAINER_SSH_KEY:-$HOME/.ssh/id_ed25519}"
  R_SANDBOX="${SANDBOX_PATH:-${REMOTE_SANDBOX_PATH:-}}"
  R_CLANG="${CLANG_VARIANT:-}"
  R_GCC="${GCC_VERSION:-}"
  if [[ -z "$R_SANDBOX" ]]; then
    R_SANDBOX="/home/${R_USER}/dev/devcontainers/cpp-devcontainer"
  fi
  
  # Deploy & Build
  log "🔨 Building & Deploying..."
  DEPLOY_STATUS="❌"
  ensure_perm_clear "$R_USER" "$R_HOST" "$R_PORT" "$R_SANDBOX"
  if "${ROOT_DIR}/scripts/deploy_remote_devcontainer.sh" >> "$PERM_LOG" 2>&1; then
    DEPLOY_STATUS="✅"
    log "✅ Deployment successful."
  else
    log "❌ Deployment failed. See ${PERM_LOG}"
  fi
  
  # 3. Verify container is running on remote host
  SSH_STATUS="⚪"
  FINAL_STATUS="**FAIL**"
  
  if [[ "$DEPLOY_STATUS" == "✅" ]]; then
    if [[ -n "$R_SANDBOX" ]]; then
      if ssh "${R_USER}@${R_HOST}" "docker ps --filter label=devcontainer.local_folder=${R_SANDBOX} -q | head -n1" >> "$PERM_LOG" 2>&1; then
        if ssh "${R_USER}@${R_HOST}" "docker ps --filter label=devcontainer.local_folder=${R_SANDBOX} -q | head -n1" | grep -q .; then
          log "✅ Container running for sandbox ${R_SANDBOX}."
        else
          log "❌ No running container found for sandbox ${R_SANDBOX}."
          SSH_STATUS="❌"
        fi
      else
        log "❌ Failed to check container status on ${R_HOST}."
        SSH_STATUS="❌"
      fi
    fi
    log "ipv4 Checking SSH connectivity..."
    if [[ "$SSH_STATUS" != "❌" ]] && "${ROOT_DIR}/scripts/test_devcontainer_ssh.sh" \
        --host "$R_HOST" \
        --port "$R_PORT" \
        --user "$R_USER" \
        --key "$R_KEY" \
        --auto-accept \
        --clang-variant "$R_CLANG" \
        --gcc-version "$R_GCC" \
        >> "$PERM_LOG" 2>&1; then
      SSH_STATUS="✅"
      FINAL_STATUS="**PASS**"
      log "✅ SSH connectivity verified."
    else
      SSH_STATUS="❌"
      log "❌ SSH connectivity failed."
    fi
  fi
  
  # Update Report
  report "| ${conf} | ${DEPLOY_STATUS} | ${SSH_STATUS} | ${FINAL_STATUS} |"

done

log "---------------------------------------------------"
log "🏁 Matrix verification complete."
log "📄 Report: ${SUMMARY_FILE}"

cat "$SUMMARY_FILE"
