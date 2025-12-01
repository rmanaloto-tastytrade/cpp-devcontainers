#!/usr/bin/env bash
set -euo pipefail

# Prints sizes for common devcontainer images.
# Usage: scripts/inspect_image_sizes.sh [tag1 tag2 ...]
# Defaults: cpp-devcontainer:local cpp-dev-base:local tools_merge:local

IMAGES=("$@")
if [[ ${#IMAGES[@]} -eq 0 ]]; then
  IMAGES=(cpp-devcontainer:local cpp-dev-base:local tools_merge:local)
fi

echo "Image size report:"
printf "%-40s %s\n" "IMAGE" "SIZE"
for img in "${IMAGES[@]}"; do
  size=$(docker images --format "{{.Repository}}:{{.Tag}}\t{{.Size}}" | awk -v target="$img" '$1==target {print $2}')
  if [[ -z "$size" ]]; then
    size="(not present)"
  fi
  printf "%-40s %s\n" "$img" "$size"
done
