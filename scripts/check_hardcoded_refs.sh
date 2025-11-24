#!/usr/bin/env bash
set -euo pipefail

# Guardrail: fail if devcontainer scripts/config contain hardcoded personal hosts/users.
# This is intentionally narrow to avoid blocking docs that may contain examples.

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT"

# Add patterns here as new personal/host strings are discovered.
PATTERNS=(
  "c24s1"
  "c0903s4"
  "c0802s4"
  "ray\.manaloto"
  "tastytrade\.com"
)

TARGETS=(
  ".devcontainer"
  "scripts"
)

PATTERN_REGEX=$(printf "(%s)" "$(IFS="|"; echo "${PATTERNS[*]}")")

echo "[check] Scanning for hardcoded personal hosts/users in ${TARGETS[*]}..."
if rg -n --glob '!scripts/check_hardcoded_refs.sh' "$PATTERN_REGEX" "${TARGETS[@]}"; then
  echo "[check] ERROR: Found hardcoded personal host/user references. Please parameterize or remove." >&2
  exit 1
else
  echo "[check] No hardcoded personal references detected in devcontainer code/scripts."
fi
