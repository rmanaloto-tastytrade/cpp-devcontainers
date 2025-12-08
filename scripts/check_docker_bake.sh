#!/usr/bin/env bash
set -euo pipefail

# Validate docker-bake.hcl syntax/targets without building.
# Usage: scripts/check_docker_bake.sh [path-to-repo-root]

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BAKE_FILE="$REPO_ROOT/.devcontainer/docker-bake.hcl"

if [[ ! -f "$BAKE_FILE" ]]; then
  echo "ERROR: Bake file not found at $BAKE_FILE" >&2
  exit 1
fi

echo "[check] Validating bake file (print): $BAKE_FILE"
if ! command -v docker >/dev/null 2>&1; then
  echo "[check] WARNING: Docker not available; skipping bake validation."
  exit 0
fi

docker buildx bake -f "$BAKE_FILE" --print devcontainer > /dev/null

if command -v hclfmt >/dev/null 2>&1; then
  echo "[check] Checking HCL formatting with hclfmt..."
  if ! hclfmt -check "$BAKE_FILE"; then
    echo "[check] WARNING: hclfmt detected format issues (non-fatal)." >&2
  fi
elif command -v terraform >/dev/null 2>&1; then
  # terraform fmt only supports .tf/.tfvars; skip for .hcl
  echo "[check] Skipping terraform fmt (unsupported for docker-bake.hcl)."
else
  echo "[check] WARNING: hclfmt/terraform not installed; skipping HCL format check." >&2
fi

if docker buildx bake --help 2>/dev/null | grep -q -- '--dry-run'; then
  echo "[check] Dry-run bake (no build)..."
  docker buildx bake -f "$BAKE_FILE" --dry-run devcontainer > /dev/null
  echo "[check] Bake file OK and dry-run passed."
else
  echo "[check] Dry-run flag not supported by this buildx; print validation passed."
fi
