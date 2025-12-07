#!/usr/bin/env bash
# Local smoke test to mirror the GHA bake invocation for devcontainers.
# Usage: TAG_BASE=... BASE_IMAGE_TAG=... BASE_CACHE_TAG=... ./scripts/ci_bake_smoke.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

TAG_BASE="${TAG_BASE:-ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/devcontainer}"
BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/cpp-dev-base:local}"
BASE_CACHE_TAG="${BASE_CACHE_TAG:-ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/cpp-dev-base:cache}"

case "${BASE_IMAGE_TAG}" in
  ghcr.io/*) ;;
  *) echo "BASE_IMAGE_TAG must point at ghcr.io (got ${BASE_IMAGE_TAG})" >&2; exit 1 ;;
esac
case "${BASE_CACHE_TAG}" in
  ghcr.io/*) ;;
  *) echo "BASE_CACHE_TAG must point at ghcr.io (got ${BASE_CACHE_TAG})" >&2; exit 1 ;;
esac

echo "Running bake smoke test with:"
echo "  TAG_BASE=${TAG_BASE}"
echo "  BASE_IMAGE_TAG=${BASE_IMAGE_TAG}"
echo "  BASE_CACHE_TAG=${BASE_CACHE_TAG}"

docker buildx bake \
  --file .devcontainer/docker-bake.hcl \
  --set base.cache-from="type=registry,ref=${BASE_CACHE_TAG}" \
  --set base.cache-to="type=registry,ref=${BASE_CACHE_TAG},mode=max,compression=zstd,oci-mediatypes=true,force-compression=true" \
  --set devcontainer_gcc14_clang_qual.args.BASE_IMAGE="${BASE_IMAGE_TAG}" \
  --set devcontainer_gcc14_clang_dev.args.BASE_IMAGE="${BASE_IMAGE_TAG}" \
  --set devcontainer_gcc14_clangp2996.args.BASE_IMAGE="${BASE_IMAGE_TAG}" \
  --set devcontainer_gcc15_clang_qual.args.BASE_IMAGE="${BASE_IMAGE_TAG}" \
  --set devcontainer_gcc15_clang_dev.args.BASE_IMAGE="${BASE_IMAGE_TAG}" \
  --set devcontainer_gcc15_clangp2996.args.BASE_IMAGE="${BASE_IMAGE_TAG}" \
  --set devcontainer_gcc14_clang_qual.cache-from="type=registry,ref=${BASE_CACHE_TAG}" \
  --set devcontainer_gcc14_clang_dev.cache-from="type=registry,ref=${BASE_CACHE_TAG}" \
  --set devcontainer_gcc14_clangp2996.cache-from="type=registry,ref=${BASE_CACHE_TAG}" \
  --set devcontainer_gcc15_clang_qual.cache-from="type=registry,ref=${BASE_CACHE_TAG}" \
  --set devcontainer_gcc15_clang_dev.cache-from="type=registry,ref=${BASE_CACHE_TAG}" \
  --set devcontainer_gcc15_clangp2996.cache-from="type=registry,ref=${BASE_CACHE_TAG}" \
  --set devcontainer_gcc14_clang_qual.tags="${TAG_BASE}:gcc14-clang21" \
  --set devcontainer_gcc14_clang_dev.tags="${TAG_BASE}:gcc14-clang22" \
  --set devcontainer_gcc14_clangp2996.tags="${TAG_BASE}:gcc14-clangp2996" \
  --set devcontainer_gcc15_clang_qual.tags="${TAG_BASE}:gcc15-clang21" \
  --set devcontainer_gcc15_clang_dev.tags="${TAG_BASE}:gcc15-clang22" \
  --set devcontainer_gcc15_clangp2996.tags="${TAG_BASE}:gcc15-clangp2996" \
  --load \
  all
