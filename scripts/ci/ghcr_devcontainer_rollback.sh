#!/usr/bin/env bash
set -euo pipefail

# Retag and republish a known-good devcontainer permutation from an existing SHA tag.
# Usage: GHCR_REPO=rmanaloto-tastytrade/SlotMap ./scripts/ci/ghcr_devcontainer_rollback.sh <permutation> <source_sha> [<target_sha>]
# Example:
#   GHCR_REPO=rmanaloto-tastytrade/SlotMap ./scripts/ci/ghcr_devcontainer_rollback.sh gcc15-clangp2996 abcd1234f... 12345678deadbeef
#
# Requirements:
#   - docker login to ghcr.io already performed (GITHUB_TOKEN or PAT with write:packages).
#   - The source tag ghcr.io/${GHCR_REPO}/devcontainer:<source_sha>-<permutation> exists.
#
# Behavior:
#   - Pulls the source SHA tag.
#   - Retags it as <permutation> and (optionally) <target_sha>-<permutation>.
#   - Pushes the new tags. DRY_RUN=1 will only print the actions.

perm="${1:-}"
source_sha="${2:-}"
target_sha="${3:-}"

if [[ -z "${GHCR_REPO:-}" ]]; then
  echo "GHCR_REPO (e.g., rmanaloto-tastytrade/SlotMap) is required" >&2
  exit 1
fi
if [[ -z "$perm" || -z "$source_sha" ]]; then
  echo "Usage: GHCR_REPO=<owner/repo> $0 <permutation> <source_sha> [<target_sha>]" >&2
  exit 1
fi

tag_base="ghcr.io/${GHCR_REPO}/devcontainer"
src="${tag_base}:${source_sha}-${perm}"
dst_main="${tag_base}:${perm}"
dst_sha="${target_sha:+${tag_base}:${target_sha}-${perm}}"

run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY RUN] $*"
  else
    echo "[RUN] $*"
    "$@"
  fi
}

run docker pull "$src"
run docker tag "$src" "$dst_main"
if [[ -n "$dst_sha" ]]; then
  run docker tag "$src" "$dst_sha"
fi
run docker push "$dst_main"
if [[ -n "$dst_sha" ]]; then
  run docker push "$dst_sha"
fi

echo "Rollback complete: ${dst_main}${dst_sha:+ and $dst_sha}"
