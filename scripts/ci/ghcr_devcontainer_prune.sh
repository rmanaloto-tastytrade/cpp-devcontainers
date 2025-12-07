#!/usr/bin/env bash
set -euo pipefail

# Prune old GHCR devcontainer SHA-tagged versions while keeping a configurable number per permutation.
# Usage:
#   GHCR_OWNER_TYPE=org GHCR_OWNER=tastytrade GHCR_PACKAGE=devcontainer ./scripts/ci/ghcr_devcontainer_prune.sh [KEEP]
# Defaults: KEEP=5, permutations hardcoded to the current matrix.
#
# Requirements:
#   - gh CLI authenticated with permissions to delete container packages (write:packages).
#   - OWNER_TYPE is either "org" or "user".
#   - Dry run by default; set DELETE=1 to actually delete.

keep="${1:-${KEEP:-5}}"
owner_type="${GHCR_OWNER_TYPE:-org}"
owner="${GHCR_OWNER:-}"
package="${GHCR_PACKAGE:-devcontainer}"
delete="${DELETE:-0}"
perms=(gcc14-clang21 gcc14-clang22 gcc14-clangp2996 gcc15-clang21 gcc15-clang22 gcc15-clangp2996)

if [[ -z "$owner" ]]; then
  echo "GHCR_OWNER is required (org or user name)" >&2
  exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

base="/orgs/${owner}"
if [[ "$owner_type" == "user" ]]; then
  base="/users/${owner}"
fi

echo "Fetching container versions for ${base}/packages/container/${package} ..."
versions_json=$(gh api -H "Accept: application/vnd.github+json" "${base}/packages/container/${package}/versions?per_page=200")

python3 - <<'PY' "$keep" "$delete" "${perms[@]}" "$versions_json" "$base" "$package"
import json
import sys
from datetime import datetime
from operator import itemgetter

keep = int(sys.argv[1])
delete_flag = sys.argv[2] == "1"
perms = sys.argv[3:-3]
versions_json = sys.argv[-3]
base = sys.argv[-2]
package = sys.argv[-1]

def created_at(ts: str) -> datetime:
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except Exception:
        return datetime.min

data = json.loads(versions_json)
bucket = {p: [] for p in perms}
for version in data:
    tags = version.get("metadata", {}).get("container", {}).get("tags", []) or []
    version_id = version.get("id")
    ts = version.get("created_at", "")
    for perm in perms:
        sha_tags = [t for t in tags if t.endswith(f"-{perm}") and t != perm]
        if sha_tags:
            bucket[perm].append({
                "id": version_id,
                "tags": sha_tags,
                "created_at": ts,
            })

deletions = []
for perm, versions in bucket.items():
    versions = sorted(versions, key=lambda v: created_at(v["created_at"]), reverse=True)
    if len(versions) <= keep:
        continue
    deletions.extend([(perm, v) for v in versions[keep:]])

if not deletions:
    print("Nothing to delete; all permutations within retention.")
    sys.exit(0)

for perm, version in deletions:
    print(f"[CANDIDATE] perm={perm} id={version['id']} tags={version['tags']} created_at={version['created_at']}")
    if delete_flag:
        import subprocess
        path = f"{base}/packages/container/{package}/versions/{version['id']}"
        subprocess.check_call(["gh", "api", "--method", "DELETE", "-H", "Accept: application/vnd.github+json", path])
        print(f"Deleted {path}")
    else:
        print("Dry run (set DELETE=1 to delete)")
PY
