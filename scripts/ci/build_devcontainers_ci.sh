#!/usr/bin/env bash
set -euo pipefail

# CI entrypoint to build (and optionally push) devcontainer permutations via docker-bake.
# This script is intended for GitHub Actions self-hosted runners but can run locally for testing.
#
# Environment:
#   PERMUTATION          Required. One of:
#                        gcc14-clang21 | gcc14-clang22 | gcc14-clangp2996 |
#                        gcc15-clang21 | gcc15-clang22 | gcc15-clangp2996
#   PUSH_IMAGES          Optional. 1 to push (default 0 -> load only).
#   TAG_BASE             Optional. Base image name (default ghcr.io/${GITHUB_REPOSITORY}/devcontainer or local-dev/devcontainer).
#   PUBLISH_LATEST       Optional. 1 to also tag latest-<permutation> (only sensible when pushing).
#   SKIP_SMOKE           Optional. 1 to skip post-build smoke tests.
#   TAG_MAP_FILE         Optional. Path to append permutation->tags mapping (default devcontainer-tags.txt).
#   TAG_MAP_PERM         Optional. If set, writes a single-line tag map to this path (overwrites).
#   EXPECTED_RUNNER_NAME Optional. If set, fail when $RUNNER_NAME does not match (cost/safety guard).
#   OUTPUT_TAR           Optional. If set, export the built image to a docker tar at this path.
#   MANIFEST_FILE        Optional. If set, writes a JSON manifest line with permutation/tags/digests.
#   CACHE_SCOPE_SALT     Optional. Extra salt appended to the buildx cache scope (defaults to $GITHUB_SHA to avoid cross-branch reuse).
#
# The script builds a single permutation target from .devcontainer/docker-bake.hcl and runs a
# lightweight smoke test inside the resulting image (clang/gcc version + VCPKG_ROOT echo).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

permutation="${PERMUTATION:-}"
if [[ -z "$permutation" ]]; then
  echo "PERMUTATION is required (e.g., gcc15-clangp2996)" >&2
  exit 1
fi

case "$permutation" in
  gcc14-clang21) target="devcontainer_gcc14_clang_qual" ; tag_suffix="gcc14-clang21" ;;
  gcc14-clang22) target="devcontainer_gcc14_clang_dev"  ; tag_suffix="gcc14-clang22" ;;
  gcc14-clangp2996) target="devcontainer_gcc14_clangp2996" ; tag_suffix="gcc14-clangp2996" ;;
  gcc15-clang21) target="devcontainer_gcc15_clang_qual" ; tag_suffix="gcc15-clang21" ;;
  gcc15-clang22) target="devcontainer_gcc15_clang_dev"  ; tag_suffix="gcc15-clang22" ;;
  gcc15-clangp2996) target="devcontainer_gcc15_clangp2996" ; tag_suffix="gcc15-clangp2996" ;;
  *) echo "Unknown PERMUTATION: $permutation" >&2; exit 1 ;;
esac
validate_target="${target/devcontainer_/validate_}"

if [[ -n "${EXPECTED_RUNNER_NAME:-}" ]]; then
  if [[ "${RUNNER_NAME:-}" != "$EXPECTED_RUNNER_NAME" ]]; then
    echo "Runner guard failed: expected '$EXPECTED_RUNNER_NAME' got '${RUNNER_NAME:-unknown}'" >&2
    exit 1
  fi
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not available" >&2
  exit 1
fi
if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx not available" >&2
  exit 1
fi

if ! docker buildx bake -f .devcontainer/docker-bake.hcl --print >/dev/null; then
  echo "bake file validation failed" >&2
  exit 1
fi

cache_mode="${BUILDX_CACHE_MODE:-local}"
ref_name="${GITHUB_REF_NAME:-local}"
event_name="${GITHUB_EVENT_NAME:-push}"
cache_scope_base="${BUILDX_CACHE_SCOPE:-${target}-${event_name}-${ref_name}}"
# Salt the cache scope so main/feature branches do not share layers by default.
cache_scope_salt="${CACHE_SCOPE_SALT:-${GITHUB_SHA:-local}}"
cache_scope="${cache_scope_base}-${cache_scope_salt}"
if [[ "${event_name}" == "pull_request" ]]; then
  cache_mode="none"
fi
cache_args=()
if [[ "$cache_mode" = "gha" ]]; then
  cache_args+=("--set" "$target.cache-from=type=gha,scope=${cache_scope}")
  cache_args+=("--set" "$target.cache-to=type=gha,scope=${cache_scope},mode=max,ignore-error=true")
  cache_args+=("--set" "$validate_target.cache-from=type=gha,scope=${cache_scope}")
  cache_args+=("--set" "$validate_target.cache-to=type=gha,scope=${cache_scope},mode=max,ignore-error=true")
elif [[ "$cache_mode" = "local" && -n "${BUILDX_CACHE_DIR:-}" ]]; then
  mkdir -p "${BUILDX_CACHE_DIR}"
  cache_args+=("--set" "$target.cache-from=type=local,src=${BUILDX_CACHE_DIR}")
  cache_args+=("--set" "$target.cache-to=type=local,dest=${BUILDX_CACHE_DIR}-new,mode=max")
  cache_args+=("--set" "$validate_target.cache-from=type=local,src=${BUILDX_CACHE_DIR}")
  cache_args+=("--set" "$validate_target.cache-to=type=local,dest=${BUILDX_CACHE_DIR}-new,mode=max")
else
  cache_args=()
fi

tag_base_default="local-dev/devcontainer"
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  tag_base_default="ghcr.io/${GITHUB_REPOSITORY}/devcontainer"
fi
tag_base="${TAG_BASE:-$tag_base_default}"
base_tag="${BASE_TAG:-cpp-cpp-dev-base:local}"

push_images="${PUSH_IMAGES:-0}"
pull_images="${PULL_IMAGES:-0}"
publish_latest="${PUBLISH_LATEST:-0}"
tag_map_file="${TAG_MAP_FILE:-devcontainer-tags.txt}"

sha_tag="${GITHUB_SHA:-local}"
tags=(
  "${tag_base}:${tag_suffix}"
  "${tag_base}:${sha_tag}-${tag_suffix}"
)
if [[ "$publish_latest" == "1" ]]; then
  tags+=("${tag_base}:latest-${tag_suffix}")
fi

tags_csv="$(IFS=, ; echo "${tags[*]}")"
push_flag="--load"
pull_flag=""
if [[ "$pull_images" == "1" ]]; then
  pull_flag="--pull"
fi
output_args=()
if [[ -n "${OUTPUT_TAR:-}" ]]; then
  output_args+=(--set "$target.output=type=docker,dest=${OUTPUT_TAR}")
fi

echo "[validate] target=$validate_target"

# Ensure base image is present locally (avoid docker.io pulls for local tags).
echo "[base] building base image: ${base_tag}"
docker buildx bake -f .devcontainer/docker-bake.hcl base \
  --set base.tags="${base_tag}" \
  --set base.output=type=docker \
  "${cache_args[@]}" \
  ${pull_flag:+$pull_flag}

docker buildx bake -f .devcontainer/docker-bake.hcl "$validate_target" \
  --no-cache \
  "${cache_args[@]}" \
  ${pull_flag:+$pull_flag}

echo "[build] target=$target tags=${tags_csv} push=${push_images}"

docker buildx bake -f .devcontainer/docker-bake.hcl "$target" \
  --set "$target.tags=${tags_csv}" \
  "${cache_args[@]}" \
  "${output_args[@]}" \
  ${pull_flag:+$pull_flag} \
  $push_flag

if [[ "${SKIP_SMOKE:-0}" != "1" ]]; then
  primary_tag="${tags[0]}"
  echo "[smoke] $primary_tag"
  docker run --rm --entrypoint /bin/bash "$primary_tag" -lc "set -e; clang --version; gcc --version; echo VCPKG_ROOT=\${VCPKG_ROOT:-unset}"
fi

if [[ -n "${BUILDX_CACHE_DIR:-}" && -d "${BUILDX_CACHE_DIR}-new" ]]; then
  rm -rf "${BUILDX_CACHE_DIR}"
  mv "${BUILDX_CACHE_DIR}-new" "${BUILDX_CACHE_DIR}"
fi

printf "%s => %s\n" "$permutation" "$tags_csv" >> "$tag_map_file"
if [[ -n "${TAG_MAP_PERM:-}" ]]; then
  printf "%s => %s\n" "$permutation" "$tags_csv" > "$TAG_MAP_PERM"
fi
if [[ -n "${MANIFEST_FILE:-}" ]]; then
  primary_tag="${tags[0]}"
  python3 - <<'PY' "$MANIFEST_FILE" "$permutation" "$tags_csv" "$primary_tag"
import json
import subprocess
import sys

manifest_file, permutation, tags_csv, primary_tag = sys.argv[1:5]

def inspect(tag: str):
    try:
        raw = subprocess.check_output(["docker", "image", "inspect", tag], text=True)
        import json as _json
        data = _json.loads(raw)[0]
        repo_digests = data.get("RepoDigests") or []
        return {"image_id": data.get("Id", ""), "repo_digests": repo_digests}
    except subprocess.CalledProcessError:
        return {"image_id": "", "repo_digests": []}

meta = inspect(primary_tag)
entry = {
    "permutation": permutation,
    "tags": tags_csv,
    "image_id": meta["image_id"],
    "repo_digests": meta["repo_digests"],
}
with open(manifest_file, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(entry) + "\n")
PY
fi
echo "[done] wrote mapping to $tag_map_file"
