#!/usr/bin/env bash
set -euo pipefail

# This script is meant to be executed directly on the remote Linux host.
# It rebuilds the sandbox workspace and launches the Dev Container via the
# Dev Containers CLI. No git changes occur in the sandbox; it is recreated
# from the clean repo checkout on every run.
#
# Directory layout (defaults can be overridden via environment variables):
#   REPO_PATH    : $HOME/dev/github/SlotMap            (clean git clone)
#   SANDBOX_PATH : $HOME/dev/devcontainers/cpp-devcontainer (recreated each run)
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
SANDBOX_PATH=${SANDBOX_PATH:-"$HOME/dev/devcontainers/cpp-devcontainer"}
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
CLANG_VARIANT=${CLANG_VARIANT:-21}
GCC_VERSION=${GCC_VERSION:-15}
DEVCONTAINER_CACHE_VOLUME=${DEVCONTAINER_CACHE_VOLUME:-cppdev-cache}
DEVCONTAINER_CXX_STD=${DEVCONTAINER_CXX_STD:-"c++26"}
export DEVCONTAINER_CACHE_VOLUME

echo "[remote] Repo source       : $REPO_PATH"
echo "[remote] Sandbox workspace : $SANDBOX_PATH"
echo "[remote] Host key cache    : $KEY_CACHE"
echo "[remote] Workspace mount   : $WORKSPACE_PATH"
echo
echo "[remote] Host capacity     : nproc=$(nproc) mem_total=$(awk 'NR==1{print $2, $3}' /proc/meminfo) docker_ncpu_mem=$(docker info --format '{{.NCPU}} {{.MemTotal}}' 2>/dev/null || true)"

BUILD_META_DIR=${BUILD_META_DIR:-"$HOME/dev/devcontainers/build_meta"}
mkdir -p "$BUILD_META_DIR"

# Default git SSH command to auto-accept new host keys (remote build git fetch)
GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-"ssh -o StrictHostKeyChecking=accept-new"}

# Cleanup: Keep only the 20 most recent builds (approx 40 files: *manifest.json + *metadata.json)
if [[ -d "$BUILD_META_DIR" ]]; then
  # Sort newest first, drop everything after the 40 newest, delete the rest
  mapfile -t meta_files < <(find "$BUILD_META_DIR" -maxdepth 1 -type f -name "*.json" -print0 | xargs -0 -r ls -1t 2>/dev/null)
  if ((${#meta_files[@]} > 40)); then
    printf '%s\0' "${meta_files[@]:40}" | xargs -0 -r rm -f 2>/dev/null || true
  fi
fi

emit_bake_manifest() {
  local target="$1"
  local ts manifest metadata
  ts="$(date +%Y%m%d%H%M%S)"
  manifest="$BUILD_META_DIR/${target}_${ts}_print.json"
  metadata="$BUILD_META_DIR/${target}_${ts}_metadata.json"
  docker buildx bake \
    -f "$SANDBOX_PATH/.devcontainer/docker-bake.hcl" \
    "$target" \
    --set '*.args.CLANG_VARIANT'"=${CLANG_VARIANT}" \
    --set '*.args.CLANG_BRANCH'"=${CLANG_BRANCH:-}" \
    --set '*.args.LLVM_APT_POCKET'"=${LLVM_APT_POCKET:-}" \
    --set '*.args.ENABLE_CLANG_P2996'"=${enable_clang_p2996_flag}" \
    --set '*.args.GCC_VERSION'"=${GCC_VERSION}" \
    --set '*.args.ENABLE_GCC15'"=${enable_gcc15_flag}" \
    --print >"$manifest"
  echo "[remote] Wrote bake manifest: $manifest"
  echo "{}" >"$metadata" # placeholder so path exists; BuildKit will overwrite when used
  export BUILDX_METADATA_FILE="$metadata"
  export BUILD_MANIFEST_PATH="$manifest"
}

if [[ -n "$DOCKER_CONTEXT" ]]; then
  echo "[remote] Using docker context: $DOCKER_CONTEXT"
  export DOCKER_CONTEXT
fi

DOCKER_CMD=(docker)
if [[ -n "$DOCKER_CONTEXT" ]]; then
  DOCKER_CMD=(docker --context "$DOCKER_CONTEXT")
fi

# Collect buildx bake flags and force no-cache when feature flags flip toolchains (e.g., p2996)
BAKE_FLAGS=()
if [[ -n "${BUILDX_BAKE_FLAGS:-}" ]]; then
  # shellcheck disable=SC2206
  BAKE_FLAGS=(${BUILDX_BAKE_FLAGS})
fi
if [[ "${CLANG_VARIANT}" == "p2996" || "${REQUIRE_P2996:-0}" == "1" || "${ENABLE_CLANG_P2996:-0}" == "1" ]]; then
  case " ${BAKE_FLAGS[*]} " in
    *" --no-cache "*) ;; # already present
    *) BAKE_FLAGS+=(--no-cache) ;;
  esac
  case " ${BAKE_FLAGS[*]} " in
    *" --progress=plain "*) ;; # already present
    *) BAKE_FLAGS+=(--progress=plain) ;;
  esac
fi
if [[ -n "${BUILDX_METADATA_FILE:-}" ]]; then
  case " ${BAKE_FLAGS[*]} " in
    *"--metadata-file"*) ;; # already present
    *) BAKE_FLAGS+=(--metadata-file "$BUILDX_METADATA_FILE") ;;
  esac
fi
enable_clang_p2996_flag=""
if [[ "${CLANG_VARIANT}" == "p2996" || "${REQUIRE_P2996:-0}" == "1" || "${ENABLE_CLANG_P2996:-0}" == "1" ]]; then
  enable_clang_p2996_flag=1
fi
enable_gcc15_flag=0
if [[ "${GCC_VERSION}" == "15" || "${ENABLE_GCC15:-0}" == "1" ]]; then
  enable_gcc15_flag=1
fi

validate_image_tools() {
  local image="$1"
  local tools=(
    "clang++-${CLANG_VARIANT}"
    "gcc-${GCC_VERSION}"
    "clang++"
    "c++"
    "gcc"
  )
  if [[ "$CLANG_VARIANT" == "p2996" ]]; then
    tools+=("/opt/clang-p2996/bin/clang++-p2996")
  fi
  local unexpected=()
  # Flag unexpected clang versions
  for v in 14 15 21 22; do
    if [[ "$CLANG_VARIANT" =~ ^[0-9]+$ && "$v" != "$CLANG_VARIANT" ]]; then
      unexpected+=("clang++-${v}")
    fi
  done
  if [[ "$CLANG_VARIANT" == "p2996" ]]; then
    unexpected+=("clang++-21" "clang++-22")
  fi
  # Flag unexpected gcc versions
  for g in 13 14 15; do
    if [[ "$GCC_VERSION" =~ ^[0-9]+$ && "$g" != "$GCC_VERSION" ]]; then
      unexpected+=("gcc-${g}" "g++-${g}")
    fi
  done

  if ! "${DOCKER_CMD[@]}" image inspect "$image" >/dev/null 2>&1; then
    echo "[remote] ERROR: image $image not found (context=${DOCKER_CONTEXT:-default})." >&2
    exit 1
  fi
  local check_script="set -euo pipefail
echo \"container nproc=\$(nproc)\"
EXPECT_CLANG=\"${CLANG_VARIANT}\"
EXPECT_GCC=\"${GCC_VERSION}\"
EXPECT_STD=\"${DEVCONTAINER_CXX_STD}\"
unexpected_list=\"${unexpected[*]}\"
for t in ${tools[*]}; do
  if ! command -v \"\$t\" >/dev/null 2>&1; then
    echo \"\${t}: MISSING\"; exit 1; fi
  ver=\$(\"\$t\" --version | head -n1 || true)
  echo \"\${t}: \${ver}\"
done
for u in \$unexpected_list; do
  if command -v \"\$u\" >/dev/null 2>&1; then
    echo \"UNEXPECTED compiler present: \$u\"; exit 1
  fi
done
# VCPKG path check
if [ ! -L /opt/vcpkg ] || [ \"\$(readlink -f /opt/vcpkg)\" != \"/cppdev-cache/vcpkg-repo\" ]; then
  echo \"VCPKG symlink invalid: /opt/vcpkg -> \$(readlink -f /opt/vcpkg 2>/dev/null)\"; exit 1
fi
if [ \"${VCPKG_ROOT:-}\" != \"/cppdev-cache/vcpkg-repo\" ]; then
  echo \"VCPKG_ROOT unexpected: ${VCPKG_ROOT:-}\"; exit 1
fi
if [ \"${CLANG_VARIANT}\" = \"p2996\" ] && [ ! -x /opt/clang-p2996/bin/clang++-p2996 ]; then
  echo \"Missing /opt/clang-p2996/bin/clang++-p2996\"; exit 1
fi
cat >/tmp/main.cpp <<'EOF'
#include <iostream>
int main() { std::cout << \"OK\" << std::endl; }
EOF
cat >/tmp/CMakeLists.txt <<EOF
cmake_minimum_required(VERSION 3.24)
project(CompileCheck LANGUAGES CXX)
set(CMAKE_CXX_STANDARD ${DEVCONTAINER_CXX_STD#c++})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
add_executable(main main.cpp)
EOF
mkdir -p /tmp/build && cd /tmp/build
env CC=\"gcc-${GCC_VERSION}\" CXX=\"clang++-${CLANG_VARIANT}\" cmake -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON /tmp || exit 1
ninja -v || exit 1
./main | grep -q OK || exit 1
if [ \"${CLANG_VARIANT}\" = \"p2996\" ]; then
  if [ ! -x /opt/clang-p2996/bin/clang++-p2996 ]; then
    echo \"Missing /opt/clang-p2996/bin/clang++-p2996\"; exit 1
  fi
  echo \"Checking libc++ linkage for p2996...\"
  rm -rf /tmp/build && mkdir -p /tmp/build && cd /tmp/build
  cat >/tmp/CMakeLists.txt <<EOF
cmake_minimum_required(VERSION 3.24)
project(CompileCheckLibcxx LANGUAGES CXX)
set(CMAKE_CXX_STANDARD ${DEVCONTAINER_CXX_STD#c++})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
add_executable(main main.cpp)
set(CMAKE_CXX_FLAGS \"-stdlib=libc++\")
set(CMAKE_EXE_LINKER_FLAGS \"-stdlib=libc++\")
EOF
  env CC=\"clang-${CLANG_VARIANT}\" CXX=\"clang++-${CLANG_VARIANT}\" cmake -G Ninja /tmp || exit 1
  ninja -v || exit 1
  ./main | grep -q OK || exit 1
fi"
  if ! printf '%s\n' "$check_script" | "${DOCKER_CMD[@]}" run --rm "$image" bash -s; then
    echo "[remote] ERROR: tool validation failed for image $image (expected clang=${CLANG_VARIANT}, gcc=${GCC_VERSION})." >&2
    exit 1
  fi
}

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

echo "[remote] Updating repo at $REPO_PATH..."
if git -C "$REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CURRENT_BRANCH="${BRANCH:-$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD)}"
  if [[ "${DEVCONTAINER_SKIP_GIT_SYNC:-0}" == "1" ]]; then
    echo "[remote] DEVCONTAINER_SKIP_GIT_SYNC=1; skipping git fetch/reset (using branch ${CURRENT_BRANCH})."
  else
    env GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o StrictHostKeyChecking=accept-new}" git -C "$REPO_PATH" fetch --all --prune
    if git -C "$REPO_PATH" show-ref --verify --quiet "refs/remotes/origin/${CURRENT_BRANCH}"; then
      git -C "$REPO_PATH" checkout "${CURRENT_BRANCH}"
      env GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o StrictHostKeyChecking=accept-new}" git -C "$REPO_PATH" reset --hard "origin/${CURRENT_BRANCH}"
    else
      env GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o StrictHostKeyChecking=accept-new}" git -C "$REPO_PATH" pull --ff-only
    fi
    env GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o StrictHostKeyChecking=accept-new}" git -C "$REPO_PATH" submodule update --init --recursive
  fi
else
  echo "[remote] ERROR: $REPO_PATH is not a git repository." >&2
  exit 1
fi

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
  emit_bake_manifest devcontainer
  "$SCRIPT_DIR/check_docker_bake.sh" "$SANDBOX_PATH"
  ensure_devcontainer_cli
  "$SCRIPT_DIR/check_devcontainer_config.sh" "$SANDBOX_PATH"
  if [[ -n "${BUILD_MANIFEST_PATH:-}" ]]; then
    # Validate manifest expectations before building
    manifest_args=(
      --manifest "$BUILD_MANIFEST_PATH"
      --expect-clang-variant "${CLANG_VARIANT:-}"
      --expect-gcc-version "${GCC_VERSION:-}"
    )
    if [[ "${enable_clang_p2996_flag}" == "1" ]]; then
      manifest_args+=(--require-tool clang++-p2996)
    fi
    python3 "$SCRIPT_DIR/tools/bake_manifest_check.py" "${manifest_args[@]}" || exit 1
  fi
  # Build base if missing
  if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
    echo "[remote] Base image $BASE_IMAGE missing; baking base..."
  docker buildx bake \
    -f "$SANDBOX_PATH/.devcontainer/docker-bake.hcl" \
    base \
    "${BAKE_FLAGS[@]}" \
    --set base.tags="$BASE_IMAGE" \
    --set '*.args.CLANG_VARIANT'="$CLANG_VARIANT" \
    --set '*.args.CLANG_BRANCH'="${CLANG_BRANCH:-}" \
    --set '*.args.LLVM_APT_POCKET'="${LLVM_APT_POCKET:-}" \
    --set '*.args.ENABLE_CLANG_P2996'="$enable_clang_p2996_flag" \
    --set '*.args.GCC_VERSION'="$GCC_VERSION" \
    --set '*.args.ENABLE_GCC15'="$enable_gcc15_flag" \
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
    "${BAKE_FLAGS[@]}" \
    --set base.tags="$BASE_IMAGE" \
    --set devcontainer.tags="$DEV_IMAGE" \
    --set '*.args.CLANG_VARIANT'="$CLANG_VARIANT" \
    --set '*.args.CLANG_BRANCH'="${CLANG_BRANCH:-}" \
    --set '*.args.LLVM_APT_POCKET'="${LLVM_APT_POCKET:-}" \
    --set '*.args.ENABLE_CLANG_P2996'="$enable_clang_p2996_flag" \
    --set '*.args.GCC_VERSION'="$GCC_VERSION" \
    --set '*.args.ENABLE_GCC15'="$enable_gcc15_flag" \
    --set '*.args.BASE_IMAGE'="$BASE_IMAGE" \
    --set '*.args.USERNAME'="$CONTAINER_USER" \
    --set '*.args.USER_UID'="$CONTAINER_UID" \
    --set '*.args.USER_GID'="$CONTAINER_GID"
  validate_image_tools "$DEV_IMAGE"
else
  echo "[remote] DEVCONTAINER_SKIP_BAKE=1; skipping bake and using image ${DEV_IMAGE}."
  validate_image_tools "$DEV_IMAGE"
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
echo "[remote] Ensuring cache volume permissions for ${DEVCONTAINER_CACHE_VOLUME}..."
"${DOCKER_CMD[@]}" run --rm -v "${DEVCONTAINER_CACHE_VOLUME}:/data" --user root "${DEV_IMAGE}" chown -R "${CONTAINER_UID}:${CONTAINER_GID}" /data

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
    env CONFIG_ENV_FILE="${CONFIG_ENV_FILE}" DEVCONTAINER_IMAGE="${DEV_IMAGE}" DEVCONTAINER_SSH_PORT="${DEVCONTAINER_SSH_PORT}" \
      "${SANDBOX_PATH}/scripts/verify_devcontainer.sh" --image "${DEV_IMAGE}" --ssh-port "${DEVCONTAINER_SSH_PORT}" --require-ssh
    echo "[remote] Running cache layout check..."
    CONFIG_ENV_FILE="${CONFIG_ENV_FILE}" \
      TARGET_CONTAINER_ID="${CONTAINER_ID}" \
      "${SANDBOX_PATH}/scripts/verify_cache_volume.sh" || true
  fi
else
  echo "[remote] WARNING: unable to locate container for inspection."
fi

echo "[remote] Devcontainer ready. Workspace: $SANDBOX_PATH"
