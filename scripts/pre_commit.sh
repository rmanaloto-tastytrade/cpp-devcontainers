#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

echo "[pre-commit] Running bake validation..."
scripts/check_docker_bake.sh "$REPO_ROOT"

echo "[pre-commit] Running devcontainer config validation (skips if Docker unavailable)..."
scripts/check_devcontainer_config.sh "$REPO_ROOT"

echo "[pre-commit] Checking for hardcoded personal hosts/users..."
scripts/check_hardcoded_refs.sh "$REPO_ROOT"

if command -v hadolint >/dev/null 2>&1; then
  echo "[pre-commit] Running hadolint on .devcontainer/Dockerfile (warnings suppressed; errors fail)..."
  if ! hadolint --failure-threshold error .devcontainer/Dockerfile >/dev/null; then
    echo "[pre-commit] hadolint detected errors (showing output):"
    hadolint --failure-threshold error .devcontainer/Dockerfile
    exit 1
  fi
else
  echo "[pre-commit] WARNING: hadolint not installed; skipping Dockerfile lint." >&2
fi

if command -v shellcheck >/dev/null 2>&1; then
  echo "[pre-commit] Running shellcheck on scripts (warnings enabled)..."
  shellcheck --severity=warning scripts/*.sh
else
  echo "[pre-commit] WARNING: shellcheck not installed; skipping shell lint." >&2
fi

echo "[pre-commit] Done."
