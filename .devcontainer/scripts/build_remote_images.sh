#!/usr/bin/env bash
set -euo pipefail

# Build devcontainer images using the remote Docker SSH context only.
# Defaults are derived from config/env/devcontainer.env.
#
# Usage:
#   .devcontainer/scripts/build_remote_images.sh [--gcc-version 14|15] [--llvm-version <21|22|qualification|development|p2996>] [--all] [--cache-dir <path>] [--builder <name>]
#
# Examples:
#   # Build default (gcc15 + clang qualification branch)
#   .devcontainer/scripts/build_remote_images.sh
#   # Build gcc14 + clang development branch (numeric resolved from apt.llvm.org)
#   .devcontainer/scripts/build_remote_images.sh --gcc-version 14 --llvm-version development
#   # Build clang-p2996 variant with gcc15
#   .devcontainer/scripts/build_remote_images.sh --llvm-version p2996
#   # Build all permutations (gcc14/15 x clang qual/dev/p2996)
#   .devcontainer/scripts/build_remote_images.sh --all

REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-"$REPO_ROOT/config/env/devcontainer.env"}"
[[ -f "$CONFIG_ENV_FILE" ]] && source "$CONFIG_ENV_FILE"

REMOTE_HOST=${DEVCONTAINER_REMOTE_HOST:-""}
REMOTE_USER=${DEVCONTAINER_REMOTE_USER:-""}
REMOTE_PORT=${DEVCONTAINER_SSH_PORT:-9222}
DOCKER_CONTEXT=${DEVCONTAINER_DOCKER_CONTEXT:-""}
BUILDER_NAME=${DEVCONTAINER_BUILDER_NAME:-"devcontainer-remote"}
CACHE_DIR_DEFAULT="/tmp/devcontainer-buildx-cache"
CACHE_DIR=${DEVCONTAINER_CACHE_DIR:-"${CACHE_DIR_DEFAULT}"}
REGISTRY_REF=${DEVCONTAINER_REGISTRY_REF:-"ghcr.io/rmanaloto-tastytrade/cpp-devcontainer"}
USE_REGISTRY_CACHE=${DEVCONTAINER_USE_REGISTRY_CACHE:-"1"}

GCC_VERSION=15
LLVM_INPUT="qualification"
BUILD_ALL=0

usage() {
  cat <<'EOF'
Usage: .devcontainer/scripts/build_remote_images.sh [options]
  --gcc-version <14|15>            GCC version to pair (default: 15)
  --llvm-version <21|22|qualification|development|p2996>
                                   Clang/LLVM variant (default: qualification → numeric via apt.llvm.org)
  --all                            Build all permutations (overrides individual selections)
  --cache-dir <path>               Cache dir on remote host for buildx local cache (default: ${CACHE_DIR})
  --builder <name>                 Buildx builder name (default: ${BUILDER_NAME})
  --registry-ref <ref>             Registry ref for cache/image outputs (default: ${REGISTRY_REF})
  --no-registry-cache              Disable registry cache; use only local cache-dir
  --verify                         After bake, run scripts/verify_devcontainer.sh on the resulting image (single-target builds only)
  -h, --help                       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gcc-version) GCC_VERSION="$2"; shift 2 ;;
    --llvm-version) LLVM_INPUT="$2"; shift 2 ;;
    --all) BUILD_ALL=1; shift ;;
    --cache-dir) CACHE_DIR="$2"; shift 2 ;;
    --builder) BUILDER_NAME="$2"; shift 2 ;;
    --registry-ref) REGISTRY_REF="$2"; shift 2 ;;
    --no-registry-cache) USE_REGISTRY_CACHE="0"; shift ;;
    --verify) VERIFY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -z "$REMOTE_HOST" || -z "$REMOTE_USER" ]] && { echo "Remote host/user not set (see config/env/devcontainer.env)"; exit 1; }

# Derive context name if not provided
if [[ -z "$DOCKER_CONTEXT" ]]; then
  DOCKER_CONTEXT="ssh-${REMOTE_HOST}"
fi

ensure_context() {
  if ! docker context inspect "$DOCKER_CONTEXT" >/dev/null 2>&1; then
    echo "Creating docker context '$DOCKER_CONTEXT' for $REMOTE_USER@$REMOTE_HOST..."
    docker context create "$DOCKER_CONTEXT" --docker "host=ssh://${REMOTE_USER}@${REMOTE_HOST}"
  else
    echo "Using docker context '$DOCKER_CONTEXT'."
  fi
}

ensure_builder() {
  if [[ -z "$BUILDER_NAME" || "$BUILDER_NAME" == "default" ]]; then
    echo "Using default builder for context ${DOCKER_CONTEXT}."
    docker --context "$DOCKER_CONTEXT" buildx use default >/dev/null 2>&1 || true
    return
  fi
  if docker --context "$DOCKER_CONTEXT" buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
    echo "Using existing buildx builder '$BUILDER_NAME' (context: $DOCKER_CONTEXT)."
    docker --context "$DOCKER_CONTEXT" buildx use "$BUILDER_NAME" >/dev/null
  else
    echo "Creating buildx builder '$BUILDER_NAME' on context $DOCKER_CONTEXT..."
    docker --context "$DOCKER_CONTEXT" buildx create --name "$BUILDER_NAME" --use --driver docker-container --platform linux/amd64 >/dev/null
    docker --context "$DOCKER_CONTEXT" buildx inspect --bootstrap "$BUILDER_NAME" >/dev/null
  fi
}

resolve_llvm() {
  local selector="$1"
  eval "$("$REPO_ROOT/.devcontainer/scripts/resolve_llvm_branches.sh" --export)"
  local qual="${LLVM_QUAL:-21}"
  local dev="${LLVM_DEV:-22}"
  case "$selector" in
    qualification|qual|"") echo "$qual" ;;
    development|dev) echo "$dev" ;;
    p2996|p2296|p2996) echo "p2996" ;;
    *) echo "$selector" ;;
  esac
}

QUAL_NUM="$(resolve_llvm qualification)"
DEV_NUM="$(resolve_llvm development)"
LLVM_VARIANT="$(resolve_llvm "$LLVM_INPUT")"

targets=()
set_args=(
  "--set" "*.platform=linux/amd64"
  "--set" "*.args.LLVM_VERSION=${LLVM_VARIANT}"
  "--set" "*.cache-from=type=local,src=${CACHE_DIR}"
  "--set" "*.cache-to=type=local,dest=${CACHE_DIR},mode=max"
)
if [[ "${USE_REGISTRY_CACHE}" == "1" && -n "${REGISTRY_REF}" ]]; then
  set_args+=(
    "--set" "*.cache-from=type=registry,ref=${REGISTRY_REF}:cache"
    "--set" "*.cache-to=type=registry,ref=${REGISTRY_REF}:cache,mode=max"
  )
fi
env_prefix=()

if [[ "$BUILD_ALL" == "1" ]]; then
  # Build full matrix; keep CLANG_QUAL/CLANG_DEV numeric in sync
  env_prefix+=(CLANG_QUAL="${QUAL_NUM}" CLANG_DEV="${DEV_NUM}")
  targets+=(matrix)
else
  case "$LLVM_VARIANT" in
    p2996) targets+=("devcontainer_gcc${GCC_VERSION}_clangp2996") ;;
    "$DEV_NUM") targets+=("devcontainer_gcc${GCC_VERSION}_clang_dev")
                env_prefix+=(CLANG_DEV="${LLVM_VARIANT}") ;;
    *) targets+=("devcontainer_gcc${GCC_VERSION}_clang_qual")
       env_prefix+=(CLANG_QUAL="${LLVM_VARIANT}") ;;
  esac
fi

echo "Remote host: ${REMOTE_USER}@${REMOTE_HOST} (port ${REMOTE_PORT}), context: ${DOCKER_CONTEXT}"
echo "Building targets: ${targets[*]} (GCC=${GCC_VERSION}, LLVM/clang=${LLVM_VARIANT})"
echo "Cache dir: ${CACHE_DIR}, builder: ${BUILDER_NAME}"

ensure_context
ensure_builder

cmd_env=("${env_prefix[@]}")
cmd_env+=("DOCKER_CONTEXT=${DOCKER_CONTEXT}")

env "${cmd_env[@]}" docker buildx bake \
  --allow=fs="/private/tmp" \
  --allow=fs="${CACHE_DIR}" \
  --allow=fs="/System/Volumes/Data/home" \
  -f "$REPO_ROOT/.devcontainer/docker-bake.hcl" \
  --progress=plain \
  "${set_args[@]}" \
  "${targets[@]}"

# Post-build verification (single target only)
if [[ "${VERIFY:-0}" == "1" ]]; then
  if [[ "${BUILD_ALL}" == "1" ]]; then
    echo "Skipping verify: --verify currently supports single-target builds only." >&2
    exit 0
  fi
  image_tag=""
  case "${targets[0]}" in
    devcontainer_gcc${GCC_VERSION}_clangp2996) image_tag="cpp-devcontainer:gcc${GCC_VERSION}-clangp2996" ;;
    devcontainer_gcc${GCC_VERSION}_clang_dev) image_tag="cpp-devcontainer:gcc${GCC_VERSION}-clang${LLVM_VARIANT}" ;;
    devcontainer_gcc${GCC_VERSION}_clang_qual) image_tag="cpp-devcontainer:gcc${GCC_VERSION}-clang${LLVM_VARIANT}" ;;
    devcontainer|default) image_tag="${TAG:-cpp-devcontainer:local}" ;;
  esac
  if [[ -z "$image_tag" ]]; then
    echo "WARNING: Could not infer image tag for target ${targets[0]}; skipping verify." >&2
    exit 0
  fi
  echo "Verifying image ${image_tag} via scripts/verify_devcontainer.sh..."
  CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-${REPO_ROOT}/config/env/devcontainer.env}" \
    "${REPO_ROOT}/scripts/verify_devcontainer.sh" --image "${image_tag}"
fi
