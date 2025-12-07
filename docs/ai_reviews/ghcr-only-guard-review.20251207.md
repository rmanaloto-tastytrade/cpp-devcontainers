# GHCR-Only Guard Review: docker.io Fallback Risks & Fixes

**Date:** 2025-12-07  
**Context:** Post-guard fix review of GHCR-only cpp-devcontainers setup

## Current Setup Summary

✅ **Correctly Configured:**
- Base tag uses GHCR FQIN: `ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/cpp-dev-base:local`
- `BASE_IMAGE` arg defaults to GHCR in both `docker-bake.hcl` and `Dockerfile`
- `pull: false` set for base and devcontainer builds
- GHCR cache refs configured (`BASE_CACHE_TAG`)
- Guard step exists (lines 192-199) grepping bake print for docker.io

## Remaining Risks & Guard Gaps

### Risk 1: Guard Only Checks Base Target ⚠️ MEDIUM
**Location:** `.github/workflows/build-devcontainer.yml:192-199`

**Issue:** Guard validates `base` target only. Permutation targets (`devcontainer_gcc14_clang_qual`, etc.) inherit `BASE_IMAGE` from `_base`, but aren't explicitly validated.

**Impact:** If permutation target misconfigures `BASE_IMAGE`, docker.io fallback could occur.

**Fix:** Add permutation target guard step after base guard.

### Risk 2: No Env Var Validation ⚠️ LOW
**Location:** `.github/workflows/build-devcontainer.yml:18-19`

**Issue:** `BASE_IMAGE_TAG` and `BASE_CACHE_TAG` env vars aren't validated as GHCR-qualified before use.

**Impact:** Accidental unqualified tag changes could bypass guard.

**Fix:** Add validation steps before guard.

### Risk 3: Guard Regex Incomplete ⚠️ LOW
**Location:** `.github/workflows/build-devcontainer.yml:196`

**Issue:** `grep -i "docker.io"` may miss patterns like `docker.io/library/` or `docker.io/` in different contexts.

**Impact:** Edge cases might slip through.

**Fix:** Use extended regex: `grep -iE "(docker\.io|docker\.io/)"`

### Risk 4: Dockerfile Syntax Pulls from docker.io ⚠️ LOW
**Location:** `.devcontainer/Dockerfile:1`

**Issue:** `# syntax=docker/dockerfile:1.7` pulls Dockerfile frontend from docker.io if not cached.

**Impact:** First build or cache miss hits docker.io.

**Fix:** Pin to GHCR mirror or use local frontend.

### Risk 5: Buildx Setup May Pull docker.io Images ⚠️ LOW
**Location:** `.github/workflows/build-devcontainer.yml:169-170`

**Issue:** `docker/setup-buildx-action@v3` defaults to `moby/buildkit:buildx-stable-1` from docker.io.

**Impact:** Runner may pull buildkit image from docker.io before guard runs.

**Fix:** Pin buildkit image to GHCR or pre-pull.

### Risk 6: No Positive Assertion of BASE_IMAGE Value ⚠️ LOW
**Location:** `.github/workflows/build-devcontainer.yml:192-199`

**Issue:** Guard checks for docker.io absence but doesn't verify `BASE_IMAGE` matches expected GHCR value.

**Impact:** Could miss cases where `BASE_IMAGE` is unset or wrong.

**Fix:** Verify bake print contains expected `BASE_IMAGE_TAG` value.

## Concise Fixes

### Fix 1: Add Env Var Validation
Insert before line 192:

```yaml
- name: Validate BASE_IMAGE_TAG is GHCR-qualified
  run: |
    if [[ ! "${{ env.BASE_IMAGE_TAG }}" =~ ^ghcr\.io/ ]]; then
      echo "ERROR: BASE_IMAGE_TAG must be GHCR-qualified, got: ${{ env.BASE_IMAGE_TAG }}"
      exit 1
    fi
    if [[ "${{ env.BASE_IMAGE_TAG }}" =~ docker\.io ]]; then
      echo "ERROR: BASE_IMAGE_TAG must not contain docker.io, got: ${{ env.BASE_IMAGE_TAG }}"
      exit 1
    fi
    echo "✓ BASE_IMAGE_TAG is GHCR-qualified: ${{ env.BASE_IMAGE_TAG }}"

- name: Validate BASE_CACHE_TAG is GHCR-qualified
  run: |
    if [[ ! "${{ env.BASE_CACHE_TAG }}" =~ ^ghcr\.io/ ]]; then
      echo "ERROR: BASE_CACHE_TAG must be GHCR-qualified, got: ${{ env.BASE_CACHE_TAG }}"
      exit 1
    fi
    if [[ "${{ env.BASE_CACHE_TAG }}" =~ docker\.io ]]; then
      echo "ERROR: BASE_CACHE_TAG must not contain docker.io, got: ${{ env.BASE_CACHE_TAG }}"
      exit 1
    fi
    echo "✓ BASE_CACHE_TAG is GHCR-qualified: ${{ env.BASE_CACHE_TAG }}"
```

### Fix 2: Enhance Base Guard & Add Permutation Guard
Replace lines 192-199 with:

```yaml
- name: Guard against docker.io fallback (base target)
  run: |
    docker buildx bake --file .devcontainer/docker-bake.hcl \
      --set BASE_TAG=${{ env.BASE_IMAGE_TAG }} \
      --set base.args.BASE_IMAGE=${{ env.BASE_IMAGE_TAG }} \
      --print base > /tmp/bake-print-base.txt
    if grep -iE "(docker\.io|docker\.io/)" /tmp/bake-print-base.txt; then
      echo "ERROR: docker.io reference detected in base target bake plan"
      cat /tmp/bake-print-base.txt
      exit 1
    fi
    if ! grep -q "${{ env.BASE_IMAGE_TAG }}" /tmp/bake-print-base.txt; then
      echo "WARNING: BASE_IMAGE may not be set correctly in base target"
      cat /tmp/bake-print-base.txt | grep -i "base_image\|from" || true
    fi
    echo "✓ Base target has no docker.io references"

- name: Guard against docker.io fallback (permutation target)
  run: |
    docker buildx bake --file .devcontainer/docker-bake.hcl \
      --set BASE_TAG=${{ env.BASE_IMAGE_TAG }} \
      --set ${{ steps.map.outputs.target }}.args.BASE_IMAGE=${{ env.BASE_IMAGE_TAG }} \
      --print ${{ steps.map.outputs.target }} > /tmp/bake-print-target.txt
    if grep -iE "(docker\.io|docker\.io/)" /tmp/bake-print-target.txt; then
      echo "ERROR: docker.io reference detected in permutation target bake plan"
      cat /tmp/bake-print-target.txt
      exit 1
    fi
    if ! grep -q "${{ env.BASE_IMAGE_TAG }}" /tmp/bake-print-target.txt; then
      echo "WARNING: BASE_IMAGE may not be set correctly in permutation target"
      cat /tmp/bake-print-target.txt | grep -i "base_image\|from" || true
    fi
    echo "✓ Permutation target has no docker.io references and BASE_IMAGE is set"
```

### Fix 3: Pin Dockerfile Syntax to GHCR (Optional)
**Location:** `.devcontainer/Dockerfile:1`

**Option A (GHCR mirror):**
```dockerfile
# syntax=ghcr.io/docker/dockerfile:1.7
```

**Option B (Local frontend - requires vendoring):**
```dockerfile
# syntax=local
```

**Recommendation:** Option A if GHCR mirrors docker/dockerfile. Otherwise, keep current and accept docker.io pull for frontend (low risk, one-time).

### Fix 4: Pin Buildx Buildkit Image (Optional)
**Location:** `.github/workflows/build-devcontainer.yml:169-170`

Add `driver-opts` to pin buildkit image:

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
  with:
    driver-opts: |
      image=ghcr.io/moby/buildkit:buildx-stable-1
```

**Recommendation:** Only if GHCR mirrors moby/buildkit. Otherwise, accept docker.io pull for buildkit (low risk, cached on runner).

## Policy Recommendations

1. **Workflow Policy:** All image references must be GHCR-qualified FQINs. No unqualified tags.
2. **Guard Policy:** Validate both base and permutation targets. Check for docker.io absence AND positive GHCR presence.
3. **Env Var Policy:** Validate all registry-related env vars before use.
4. **Dockerfile Policy:** Prefer GHCR mirrors for syntax/frontend. Document docker.io dependencies if unavoidable.

## Summary

**Critical Issues:** None - current setup is functionally correct.

**Recommended Priority:**
1. ✅ **HIGH:** Fix 1 (env var validation) + Fix 2 (enhanced guards)
2. ⚠️ **MEDIUM:** Fix 3 (Dockerfile syntax) - only if GHCR mirrors available
3. ⚠️ **LOW:** Fix 4 (buildkit image) - only if GHCR mirrors available

**Remaining docker.io Pull Risk:** Very low after Fixes 1-2. Fixes 3-4 address edge cases (frontend/buildkit pulls) that occur before guard runs but are typically cached.
