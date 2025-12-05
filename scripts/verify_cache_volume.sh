#!/usr/bin/env bash
set -euo pipefail

# Validate the shared cache volume layout inside a running devcontainer.
# - Ensures /cppdev-cache exists with expected subdirectories.
# - Confirms /opt/vcpkg is a symlink to the cached checkout.
# - Prints sizes to help spot unexpected growth.
#
# Usage:
#   CONFIG_ENV_FILE=config/env/devcontainer.env scripts/verify_cache_volume.sh
# Optional:
#   TARGET_CONTAINER_ID=<container_id>  # if omitted, first running container for the image is used

REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-"$REPO_ROOT/config/env/devcontainer.env"}"
# shellcheck source=/dev/null
[[ -f "$CONFIG_ENV_FILE" ]] && source "$CONFIG_ENV_FILE"

IMAGE_TAG="${DEVCONTAINER_IMAGE:-cpp-devcontainer:gcc15-clangp2996}"
DOCKER_CONTEXT=${DEVCONTAINER_DOCKER_CONTEXT:-""}
DOCKER_CMD=(docker)
if [[ -n "$DOCKER_CONTEXT" ]]; then
  DOCKER_CMD+=(--context "$DOCKER_CONTEXT")
fi

container_id="${TARGET_CONTAINER_ID:-}"
if [[ -z "$container_id" ]]; then
  container_id="$("${DOCKER_CMD[@]}" ps --filter "ancestor=${IMAGE_TAG}" --filter "status=running" --format '{{.ID}}' | head -n1)"
fi

if [[ -z "$container_id" ]]; then
  echo "[cache-verify] ERROR: no running container found for image ${IMAGE_TAG}. Start the devcontainer first." >&2
  exit 1
fi

required_dirs=(ccache sccache tmp vcpkg-archives vcpkg-downloads vcpkg-repo)
cache_root="/cppdev-cache"
vcpkg_link="/opt/vcpkg"
expected_vcpkg_target="${cache_root}/vcpkg-repo"

echo "[cache-verify] Container: ${container_id}"
echo "[cache-verify] Image    : ${IMAGE_TAG}"
echo "[cache-verify] Checking cache root at ${cache_root}..."

fail=0
if ! "${DOCKER_CMD[@]}" exec "${container_id}" test -d "${cache_root}"; then
  echo "[cache-verify] ERROR: ${cache_root} missing."
  exit 1
fi

for d in "${required_dirs[@]}"; do
  if ! "${DOCKER_CMD[@]}" exec "${container_id}" test -d "${cache_root}/${d}"; then
    echo "[cache-verify] ERROR: missing ${cache_root}/${d}"
    fail=1
  fi
done

vcpkg_target="$("${DOCKER_CMD[@]}" exec "${container_id}" readlink -f "${vcpkg_link}" 2>/dev/null || true)"
if [[ "${vcpkg_target}" != "${expected_vcpkg_target}" ]]; then
  echo "[cache-verify] ERROR: ${vcpkg_link} -> ${vcpkg_target:-<missing>} (expected ${expected_vcpkg_target})"
  fail=1
else
  echo "[cache-verify] OK: ${vcpkg_link} -> ${vcpkg_target}"
fi

echo "[cache-verify] Cache usage:"
"${DOCKER_CMD[@]}" exec "${container_id}" sh -c "du -sh ${cache_root}/* 2>/dev/null || true"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "[cache-verify] Cache layout OK."
