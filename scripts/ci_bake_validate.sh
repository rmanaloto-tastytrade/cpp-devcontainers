#!/usr/bin/env bash
# Quick validation-only check: print bake plan and fail on docker.io/library refs.
# Usage: ./scripts/ci_bake_validate.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

docker buildx bake --file .devcontainer/docker-bake.hcl --print all > /tmp/bake-validate-plan.txt

if grep -Ei "docker\\.io|library/" /tmp/bake-validate-plan.txt; then
  echo "docker.io reference detected in bake plan"
  exit 1
fi

echo "Bake validation OK (no docker.io/library references)."
