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
    # 1. Stop/Remove project containers (filter by ancestor)
    docker ps -a --filter 'ancestor=cpp-cpp-devcontainer' --filter 'ancestor=cpp-cpp-dev-base' --format '{{.ID}}' | xargs -r docker rm -f
    
    # 2. Remove project images
    docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^(cpp-cpp-devcontainer|cpp-cpp-dev-base)' | xargs -r docker rmi -f
    
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

# Initialize Report
echo "# Devcontainer Matrix Verification Report" > "$SUMMARY_FILE"
echo "Date: $(date)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "| Config | Deploy | SSH check | Status |" >> "$SUMMARY_FILE"
echo "|---|---|---|---|" >> "$SUMMARY_FILE"

log "🚀 Starting Matrix Verification. Logs: ${LOG_DIR}"

for conf in "${CONFIGS[@]}"; do
  if [[ -n "$HOST_ENV_PREFIX" ]]; then
    ENV_FILE="${ROOT_DIR}/config/env/${HOST_ENV_PREFIX}.${conf}.env"
  else
    # Auto-detect the first matching env file for this permutation
    ENV_FILE="$(ls -1 "${ROOT_DIR}"/config/env/devcontainer.*.${conf}.env 2>/dev/null | head -n 1 || true)"
  fi
  PERM_LOG="${LOG_DIR}/${conf}.log"
  
  log "---------------------------------------------------"
  log "Testing Permutation: ${conf}"
  [[ -n "$ENV_FILE" ]] && log "Using env file: ${ENV_FILE}"
  
  if [[ ! -f "$ENV_FILE" ]]; then
    log "❌ Config verify failed: ${ENV_FILE} missing."
    report "| ${conf} | ❌ Missing | ⚪ | **SKIPPED** |"
    continue
  fi

  # Extract remote details for cleanup
  # Run in subshell to avoid polluting current env
  # shellcheck source=/dev/null
  REMOTE_DETAILS=$(set -a && source "$ENV_FILE" && set +a && echo "${DEVCONTAINER_REMOTE_USER}:${DEVCONTAINER_REMOTE_HOST}:${DEVCONTAINER_SSH_PORT:-9222}")
  IFS=':' read -r R_USER R_HOST R_PORT <<< "$REMOTE_DETAILS"
  
  # 1. Cleanup
  cleanup_remote "$R_USER" "$R_HOST" >> "$PERM_LOG" 2>&1
  
  # 2. Deploy & Build
  log "🔨 Building & Deploying..."
  DEPLOY_STATUS="❌"
  # shellcheck source=/dev/null
  if (set -a && source "$ENV_FILE" && set +a && "${ROOT_DIR}/scripts/deploy_remote_devcontainer.sh" >> "$PERM_LOG" 2>&1); then
    DEPLOY_STATUS="✅"
    log "✅ Deployment successful."
  else
    log "❌ Deployment failed. See ${PERM_LOG}"
  fi
  
  # 3. Verify SSH (Only if deploy succeeded)
  SSH_STATUS="⚪"
  FINAL_STATUS="**FAIL**"
  
  if [[ "$DEPLOY_STATUS" == "✅" ]]; then
    log "ipv4 Checking SSH connectivity..."
    if "${ROOT_DIR}/scripts/test_devcontainer_ssh.sh" --host "$R_HOST" --port "$R_PORT" --auto-accept >> "$PERM_LOG" 2>&1; then
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
