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
#   --image cpp-devcontainer:gcc15-clangp2996
#   --ssh-port ${DEVCONTAINER_SSH_PORT:-9222}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-"$REPO_ROOT/config/env/devcontainer.env"}"
# shellcheck source=/dev/null
[[ -f "$CONFIG_ENV_FILE" ]] && source "$CONFIG_ENV_FILE"

# Optional clang branch resolver
CLANG_UTILS_PATH="$REPO_ROOT/scripts/clang_branch_utils.sh"
if [[ -f "$CLANG_UTILS_PATH" ]]; then
  # shellcheck source=/dev/null
  source "$CLANG_UTILS_PATH"
  resolve_clang_branch
fi

IMAGE_TAG="${DEVCONTAINER_IMAGE:-cpp-devcontainer:gcc15-clangp2996}"
SSH_PORT="${DEVCONTAINER_SSH_PORT:-9222}"
PATH_PREFIX="/usr/local/bin:/opt/clang-p2996/bin:/opt/gcc-15/bin"

REQUIRE_SSH=0

# Expected mutagen version (installed in image build)
# shellcheck disable=SC2034 # consumed in generated check script
EXPECTED_MUTAGEN_VERSION="${MUTAGEN_VERSION:-0.18.1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE_TAG="$2"; shift 2 ;;
    --ssh-port) SSH_PORT="$2"; shift 2 ;;
    --require-ssh) REQUIRE_SSH=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--image <tag>] [--ssh-port <port>] [--require-ssh]
Defaults: --image cpp-devcontainer:gcc15-clangp2996, --ssh-port ${SSH_PORT}
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

REMOTE_HOST=${DEVCONTAINER_REMOTE_HOST:?set DEVCONTAINER_REMOTE_HOST}
REMOTE_USER=${DEVCONTAINER_REMOTE_USER:?set DEVCONTAINER_REMOTE_USER}
CONTAINER_SSH_USER=${CONTAINER_USER:-${DEVCONTAINER_USER:-${REMOTE_USER}}}
SSH_KEY_PATH=${DEVCONTAINER_SSH_KEY:-${DEVCONTAINER_SSH_KEY_PATH:-${SSH_KEY_PATH:-"$HOME/.ssh/id_ed25519"}}}
DOCKER_CONTEXT=${DEVCONTAINER_DOCKER_CONTEXT:-""}
DOCKER_CMD=(docker)
if [[ -n "$DOCKER_CONTEXT" ]]; then
  DOCKER_CMD+=(--context "$DOCKER_CONTEXT")
fi

echo "[verify] Using docker context: ${DOCKER_CONTEXT:-<none>}"
echo "[verify] Checking image: ${IMAGE_TAG}"

# Infer expected compilers from env or image tag
EXPECTED_CLANG="${CLANG_VARIANT:-}"
EXPECTED_GCC="${GCC_VERSION:-}"
REQUIRE_P2996="${REQUIRE_P2996:-}"
IMAGE_LOWER="${IMAGE_TAG,,}"
if [[ -z "$EXPECTED_CLANG" ]]; then
  if [[ "$IMAGE_LOWER" == *"clangp2996"* ]]; then
    EXPECTED_CLANG="p2996"
  elif [[ "$IMAGE_LOWER" == *"clang22"* ]]; then
    EXPECTED_CLANG="22"
  else
    EXPECTED_CLANG="21"
  fi
fi
if [[ -z "$EXPECTED_GCC" ]]; then
  if [[ "$IMAGE_LOWER" == *"gcc15"* ]]; then
    EXPECTED_GCC="15"
  else
    EXPECTED_GCC="14"
  fi
fi
if [[ "$EXPECTED_CLANG" == "p2996" ]]; then
  REQUIRE_P2996="${REQUIRE_P2996:-1}"
fi
EXPECTED_CLANG_CMD="clang++-${EXPECTED_CLANG}"
if [[ "$EXPECTED_CLANG" == "p2996" ]]; then
  EXPECTED_CLANG_CMD="clang++-p2996"
fi
EXPECTED_GCC_CMD=""
if [[ -n "$EXPECTED_GCC" ]]; then
  EXPECTED_GCC_CMD="gcc-${EXPECTED_GCC}"
fi
REQUIRED_TOOLS=("${EXPECTED_CLANG_CMD}")
[[ -n "$EXPECTED_GCC_CMD" ]] && REQUIRED_TOOLS+=("${EXPECTED_GCC_CMD}")
REQUIRED_TOOLS+=(ninja cmake vcpkg mrdocs)
REQUIRED_TOOLS+=(mutagen)
REQUIRED_TOOLS_STR="${REQUIRED_TOOLS[*]}"

echo "[verify] Expected clang: ${EXPECTED_CLANG_CMD}; expected gcc: ${EXPECTED_GCC_CMD:-<none>}"

build_check_script() {
  cat <<'EOF'
set +e
PATH="__PATH_PREFIX__:${PATH}"
missing=0
echo "user: $(whoami)"
check() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    case "$tool" in
      cmake) echo "$tool: $(cmake --version | head -n1)";;
      vcpkg) echo "$tool: $(vcpkg version | head -n1)";;
      mrdocs) echo "$tool: $(mrdocs --version | head -n1)";;
      mutagen)
        local out ver
        out="$(mutagen version 2>/dev/null | head -n1 || true)"
        ver="$(printf '%s' "$out" | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')"
        if [[ -n "$EXPECTED_MUTAGEN_VERSION" && "$ver" != "${EXPECTED_MUTAGEN_VERSION#v}" && "$ver" != "$EXPECTED_MUTAGEN_VERSION" ]]; then
          echo "$tool: $out (EXPECTED ${EXPECTED_MUTAGEN_VERSION})"
          missing=1
        else
          echo "$tool: ${out:-<no output>}"
        fi
        ;;
      *) echo "$tool: $("$tool" --version | head -n1)";;
    esac
  else
    echo "$tool: MISSING"
    missing=1
  fi
}
for tool in __REQUIRED_TOOLS__; do
  check "$tool"
done
exit $missing
EOF
}

CHECK_SCRIPT="$(build_check_script)"
CHECK_SCRIPT="${CHECK_SCRIPT//__PATH_PREFIX__/${PATH_PREFIX}}"
CHECK_SCRIPT="${CHECK_SCRIPT//__REQUIRED_TOOLS__/${REQUIRED_TOOLS_STR}}"

# Ensure image exists on remote
if ! "${DOCKER_CMD[@]}" image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
  echo "[verify] ERROR: image ${IMAGE_TAG} not found on ${REMOTE_HOST}" >&2
  exit 1
fi

echo "[verify] Running tool checks inside ${IMAGE_TAG}..."
printf '%s\n' "${CHECK_SCRIPT}" | "${DOCKER_CMD[@]}" run --rm \
  "${IMAGE_TAG}" \
  bash -s

# Optional SSH verification against a running devcontainer
ssh-keygen -R "[${REMOTE_HOST}]:${SSH_PORT}" >/dev/null 2>&1 || true
ssh-keygen -R "[127.0.0.1]:${SSH_PORT}" >/dev/null 2>&1 || true
echo "[verify] Attempting SSH tool check on ${REMOTE_HOST}:${SSH_PORT} (direct, then ProxyJump fallback)..."
SSH_ERR_LOG="/tmp/verify_ssh_err.log"
SSH_STRICT=(-o StrictHostKeyChecking=accept-new)
SSH_CMD_PROXY=(ssh -i "${SSH_KEY_PATH}" -o IdentitiesOnly=yes "${SSH_STRICT[@]}" -J "${REMOTE_USER}@${REMOTE_HOST}" -p "${SSH_PORT}" "${CONTAINER_SSH_USER}@127.0.0.1")
SSH_CMD_DIRECT=(ssh -i "${SSH_KEY_PATH}" -o IdentitiesOnly=yes "${SSH_STRICT[@]}" -p "${SSH_PORT}" "${CONTAINER_SSH_USER}@${REMOTE_HOST}")
SSH_CMD_LOCALHOST=(ssh -i "${SSH_KEY_PATH}" -o IdentitiesOnly=yes "${SSH_STRICT[@]}" -p "${SSH_PORT}" "${CONTAINER_SSH_USER}@127.0.0.1")
set +u
SSH_TARGET_CMD=$(cat <<EOF
cat <<'EOS' >/tmp/verify_devcontainer.sh
${CHECK_SCRIPT}
EOS
bash /tmp/verify_devcontainer.sh
RC=\$?
rm -f /tmp/verify_devcontainer.sh
if [ \$RC -ne 0 ]; then exit \$RC; fi

# Ensure cache dirs point at the volume
check_cache_dir() {
  local name="$1" path="$2"
  if [ ! -d "$path" ]; then
    echo "[verify] ERROR: cache dir missing: ${name} at ${path}"
    return 1
  fi
  case "$path" in
    /cppdev-cache/*) ;;
    *)
      echo "[verify] ERROR: cache dir ${name} expected under /cppdev-cache but got ${path}"
      return 1
      ;;
  esac
  echo "[verify] cache ${name}: ${path}"
}
check_cache_dir CCACHE_DIR "${CCACHE_DIR:-/cppdev-cache/ccache}" || exit 1
check_cache_dir CCACHE_HOME "${CCACHE_HOME:-/cppdev-cache/ccache}" || exit 1
check_cache_dir SCCACHE_DIR "${SCCACHE_DIR:-/cppdev-cache/sccache}" || exit 1
if [ ! -L /opt/vcpkg ]; then
  echo "[verify] ERROR: /opt/vcpkg is not a symlink to the cache repo"
  exit 1
fi
target=$(readlink -f /opt/vcpkg 2>/dev/null || readlink /opt/vcpkg)
case "$target" in
  /cppdev-cache/*) ;;
  *) echo "[verify] ERROR: /opt/vcpkg -> $target (expected under /cppdev-cache)"; exit 1;;
esac
if [ ! -x /opt/vcpkg/vcpkg ]; then echo "[verify] ERROR: vcpkg binary missing at /opt/vcpkg/vcpkg"; exit 1; fi
echo "[verify] vcpkg repo: /opt/vcpkg -> $target"
exit 0
EOF
)
set -u

SSH_OK=0
if "${SSH_CMD_DIRECT[@]}" "${SSH_TARGET_CMD}" 2>"${SSH_ERR_LOG}"; then
  SSH_OK=1
else
  echo "[verify] Direct SSH failed; retrying with ProxyJump..." >&2
  if "${SSH_CMD_PROXY[@]}" "${SSH_TARGET_CMD}" 2>"${SSH_ERR_LOG}.proxy"; then
    SSH_OK=1
    mv "${SSH_ERR_LOG}.proxy" "${SSH_ERR_LOG}" 2>/dev/null || true
  elif [[ "${REMOTE_HOST}" != "127.0.0.1" && "${REMOTE_HOST}" != "localhost" ]]; then
    echo "[verify] ProxyJump failed; retrying direct localhost connection..." >&2
    if "${SSH_CMD_LOCALHOST[@]}" "${SSH_TARGET_CMD}" 2>"${SSH_ERR_LOG}.localhost"; then
      SSH_OK=1
      mv "${SSH_ERR_LOG}.localhost" "${SSH_ERR_LOG}" 2>/dev/null || true
    fi
  fi
fi

if [[ "${SSH_OK}" -eq 1 ]]; then
  echo "[verify] SSH tool check succeeded on port ${SSH_PORT}."
else
  echo "[verify] WARNING: SSH tool check failed or container not running. See /tmp/verify_ssh_err.log for details." >&2
  if [[ "${REQUIRE_SSH}" == "1" ]]; then
    exit 1
  fi
fi

# Optional Mutagen validation (two-way sync) if requested
if [[ "${REQUIRE_MUTAGEN:-0}" == "1" ]]; then
  echo "[verify] Running Mutagen validation..."
  CONFIG_ENV_FILE="${CONFIG_ENV_FILE}" "${SCRIPT_DIR}/verify_mutagen.sh"
fi
