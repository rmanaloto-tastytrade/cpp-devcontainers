#!/usr/bin/env bash
set -euo pipefail

# Validate devcontainer.json by parsing it with the Dev Containers CLI.
# Usage: scripts/check_devcontainer_config.sh [path-to-repo-root]

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_PATH="$REPO_ROOT/.devcontainer/devcontainer.json"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "ERROR: devcontainer.json not found at $CONFIG_PATH" >&2
  exit 1
fi

echo "[check] Validating devcontainer config: $CONFIG_PATH"
if ! docker info >/dev/null 2>&1; then
  echo "[check] WARNING: Docker not available; skipping devcontainer config validation."
  exit 0
fi
devcontainer read-configuration --workspace-folder "$REPO_ROOT" --include-merged-configuration >/dev/null
echo "[check] devcontainer config OK."
