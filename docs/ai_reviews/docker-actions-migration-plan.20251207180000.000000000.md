# Docker Actions Migration Plan: Unified CI Helper + Devcontainer Workflow

**Date:** 2025-12-07  
**Target Repo:** rmanaloto-tastytrade/cpp-devcontainers  
**GHCR Namespace:** ghcr.io/rmanaloto-tastytrade/cpp-devcontainers

## Overview

Migrate `publish-ci-helper.yml` and `build-devcontainer.yml` into a single unified workflow using official Docker actions (`docker/bake-action`, `docker/build-push-action`, `docker/login-action`, `docker/metadata-action`, `docker/setup-buildx-action`, `docker/setup-qemu-action`). Both CI helper and devcontainer builds use `docker-bake.hcl` for consistency.

## Workflow Structure

### Filename
`YYYYMMDDHHMMSS.<9-digit-nanos>.yml` (e.g., `20251207180000.000000000.yml`)

### Triggers
```yaml
on:
  push:
    branches: [main, modernization.20251118]
    paths:
      - '.github/ci/**'
      - '.devcontainer/**'
      - 'docker-bake.hcl'
      - '.github/workflows/*.yml'
  workflow_dispatch:
```

### Concurrency
```yaml
concurrency:
  group: ci-devcontainers-${{ github.ref }}-${{ github.event_name }}
  cancel-in-progress: true
```

## Job 1: build-ci-helper

**Purpose:** Build and push CI helper image (prerequisite for devcontainer builds)

**Runner:** `[self-hosted, devcontainer-builder, c0802s4]`

**Permissions:**
```yaml
permissions:
  contents: read
  packages: write
  id-token: write  # For GHCR OIDC (optional, can use GITHUB_TOKEN)
```

**Environment Variables:**
```yaml
env:
  CI_HELPER_IMAGE: ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/ci-helper
  EXPECTED_RUNNER_NAME: c0802s4-000
  EXPECTED_RUNNER_ALT: c0802s4
  DOCKER_BUILDKIT: 1
  BUILDX_NO_DEFAULT_LOAD: 1
```

**Steps:**

1. **Runner Guard**
   ```yaml
   - name: Runner guard
     run: |
       actual="$(hostname)"
       expected="${EXPECTED_RUNNER_NAME:-}"
       alt="${EXPECTED_RUNNER_ALT:-}"
       if [ -n "$expected" ] && [ "$actual" != "$expected" ] && { [ -z "$alt" ] || [ "$actual" != "$alt" ]; }; then
         echo "Runner guard failed: expected ${expected}${alt:+ or ${alt}}, got ${actual}"
         exit 1
       fi
   ```

2. **Checkout**
   ```yaml
   - name: Checkout
     uses: actions/checkout@v4
   ```

3. **Setup Docker Buildx**
   ```yaml
   - name: Set up Docker Buildx
     uses: docker/setup-buildx-action@v3
     with:
       driver-opts: |
         network=host
       # Optional: use docker-container driver for better cache isolation
       # driver: docker-container
   ```

4. **Login to GHCR**
   ```yaml
   - name: Login to GHCR
     uses: docker/login-action@v3
     with:
       registry: ghcr.io
       username: ${{ github.actor }}
       password: ${{ secrets.GITHUB_TOKEN }}
   ```

5. **Generate Metadata**
   ```yaml
   - name: Generate metadata
     id: meta-helper
     uses: docker/metadata-action@v5
     with:
       images: ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/ci-helper
       tags: |
         type=sha,format=short,prefix=
         type=raw,value=latest
       labels: |
         org.opencontainers.image.title=CI Helper
         org.opencontainers.image.description=CI helper image with Docker CLI, buildx, devcontainers CLI, hadolint
         org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}
         org.opencontainers.image.revision=${{ github.sha }}
   ```

6. **Build and Push CI Helper via Bake**
   ```yaml
   - name: Build and push CI helper
     uses: docker/bake-action@v6
     with:
       files: docker-bake.hcl
       targets: ci-helper
       push: true
       set: |
         ci-helper.tags=${{ steps.meta-helper.outputs.tags }}
         ci-helper.labels=${{ steps.meta-helper.outputs.labels }}
       cache-from: type=gha,scope=ci-helper-${{ github.ref_name }}
       cache-to: type=gha,scope=ci-helper-${{ github.ref_name }},mode=max
   ```

7. **Cleanup (always)**
   ```yaml
   - name: Cleanup runner
     if: always()
     run: |
       docker builder prune -f --filter until=24h || true
       docker image prune -f --filter until=24h || true
   ```

**Note:** Requires `ci-helper` target in `docker-bake.hcl` (see "Required Changes" section).

## Job 2: build-devcontainers

**Purpose:** Build devcontainer matrix permutations (depends on CI helper)

**Runner:** `[self-hosted, devcontainer-builder, c0802s4]`

**Dependencies:** `needs: build-ci-helper`

**Matrix Strategy:**
```yaml
strategy:
  fail-fast: false
  matrix:
    permutation:
      - gcc14-clang21
      - gcc14-clang22
      - gcc14-clangp2996
      - gcc15-clang21
      - gcc15-clang22
      - gcc15-clangp2996
```

**Conditional Execution:**
```yaml
if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository
```

**Permissions:** Same as Job 1

**Environment Variables:**
```yaml
env:
  TAG_BASE: ghcr.io/${{ github.repository }}/devcontainer
  EXPECTED_RUNNER_NAME: c0802s4-000
  EXPECTED_RUNNER_ALT: c0802s4
  CI_HELPER_IMAGE: ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/ci-helper:latest
  DOCKER_BUILDKIT: 1
  BUILDX_NO_DEFAULT_LOAD: 1
```

**Steps:**

1. **Runner Guard** (same as Job 1)

2. **Checkout**
   ```yaml
   - name: Checkout
     uses: actions/checkout@v4
   ```

3. **Ensure CI Helper Image**
   ```yaml
   - name: Ensure CI helper image
     run: |
       if ! docker pull "$CI_HELPER_IMAGE"; then
         echo "Helper image not found; this should not happen if build-ci-helper succeeded"
         exit 1
       fi
   ```

4. **Lint Dockerfile (hadolint)**
   ```yaml
   - name: Lint Dockerfile
     run: |
       docker run --rm -i \
         -v "$PWD":/workspace -w /workspace \
         "$CI_HELPER_IMAGE" \
         bash -lc 'hadolint --failure-threshold error - < .devcontainer/Dockerfile'
   ```

5. **Preflight Validation**
   ```yaml
   - name: Preflight devcontainer/bake validation
     run: |
       docker run --rm \
         -v "$PWD":/workspace -w /workspace \
         -v /var/run/docker.sock:/var/run/docker.sock \
         "$CI_HELPER_IMAGE" \
         bash -lc './scripts/check_docker_bake.sh && devcontainer read-configuration --workspace-folder . >/tmp/devcontainer-config.json && ./scripts/check_devcontainer_config.sh'
   ```

6. **Setup Docker Buildx**
   ```yaml
   - name: Set up Docker Buildx
     uses: docker/setup-buildx-action@v3
     with:
       driver-opts: |
         network=host
   ```

7. **Login to GHCR** (conditional on push to main)
   ```yaml
   - name: Login to GHCR
     if: github.event_name == 'push' && github.ref == 'refs/heads/main'
     uses: docker/login-action@v3
     with:
       registry: ghcr.io
       username: ${{ github.actor }}
       password: ${{ secrets.GITHUB_TOKEN }}
   ```

8. **Generate Metadata for Devcontainer**
   ```yaml
   - name: Generate metadata
     id: meta-devcontainer
     uses: docker/metadata-action@v5
     with:
       images: ${{ env.TAG_BASE }}
       tags: |
         type=sha,format=short,prefix=${{ matrix.permutation }}-
         type=raw,value=${{ matrix.permutation }}
         type=raw,value=latest-${{ matrix.permutation }},enable=${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
       labels: |
         org.opencontainers.image.title=Devcontainer (${{ matrix.permutation }})
         org.opencontainers.image.description=C++ devcontainer image with GCC/Clang toolchain
         org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}
         org.opencontainers.image.revision=${{ github.sha }}
   ```

9. **Map Permutation to Bake Target**
   ```yaml
   - name: Map permutation to bake target
     id: target-map
     run: |
       case "${{ matrix.permutation }}" in
         gcc14-clang21) echo "target=devcontainer_gcc14_clang_qual" >> $GITHUB_OUTPUT ;;
         gcc14-clang22) echo "target=devcontainer_gcc14_clang_dev" >> $GITHUB_OUTPUT ;;
         gcc14-clangp2996) echo "target=devcontainer_gcc14_clangp2996" >> $GITHUB_OUTPUT ;;
         gcc15-clang21) echo "target=devcontainer_gcc15_clang_qual" >> $GITHUB_OUTPUT ;;
         gcc15-clang22) echo "target=devcontainer_gcc15_clang_dev" >> $GITHUB_OUTPUT ;;
         gcc15-clangp2996) echo "target=devcontainer_gcc15_clangp2996" >> $GITHUB_OUTPUT ;;
         *) echo "Unknown permutation" >&2; exit 1 ;;
       esac
   ```

10. **Build Devcontainer via Bake** (no push for PRs)
    ```yaml
    - name: Build devcontainer
      uses: docker/bake-action@v6
      with:
        files: .devcontainer/docker-bake.hcl
        targets: ${{ steps.target-map.outputs.target }}
        push: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
        load: ${{ github.event_name != 'push' || github.ref != 'refs/heads/main' }}
        set: |
          ${{ steps.target-map.outputs.target }}.tags=${{ steps.meta-devcontainer.outputs.tags }}
          ${{ steps.target-map.outputs.target }}.labels=${{ steps.meta-devcontainer.outputs.labels }}
        cache-from: type=gha,scope=devcontainer-${{ matrix.permutation }}-${{ github.ref_name }}
        cache-to: type=gha,scope=devcontainer-${{ matrix.permutation }}-${{ github.ref_name }},mode=max
    ```

11. **Export Image Tar** (for artifact upload)
    ```yaml
    - name: Export image tar
      if: always()
      run: |
        primary_tag="${{ env.TAG_BASE }}:${{ matrix.permutation }}"
        docker save "$primary_tag" -o /tmp/devcontainer-${{ matrix.permutation }}.tar || true
    ```

12. **Generate Tag Map**
    ```yaml
    - name: Generate tag map
      if: always()
      run: |
        tags="${{ steps.meta-devcontainer.outputs.tags }}"
        echo "${{ matrix.permutation }} => $tags" >> /tmp/tag-map-${{ matrix.permutation }}.txt
    ```

13. **Upload Artifacts**
    ```yaml
    - name: Upload image tar
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: devcontainer-image-${{ matrix.permutation }}
        path: /tmp/devcontainer-${{ matrix.permutation }}.tar
        retention-days: 3
        if-no-files-found: ignore

    - name: Upload tag map
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: tag-map-${{ matrix.permutation }}
        path: /tmp/tag-map-${{ matrix.permutation }}.txt
        retention-days: 7
        if-no-files-found: ignore
    ```

14. **Cleanup Runner** (always)
    ```yaml
    - name: Cleanup runner
      if: always()
      run: |
        rm -f /tmp/devcontainer-${{ matrix.permutation }}.tar /tmp/tag-map-${{ matrix.permutation }}.txt || true
        docker builder prune -f --filter until=24h || true
        docker image prune -f --filter until=24h || true
    ```

## Job 3: publish-devcontainers (Optional)

**Purpose:** Consolidate artifacts, scan, and push final tags (only for main branch pushes)

**Runner:** `[self-hosted, devcontainer-builder, c0802s4-000]`

**Dependencies:** `needs: build-devcontainers`

**Condition:** `if: github.event_name == 'push' && github.ref == 'refs/heads/main'`

**Steps:**

1. **Download Artifacts**
   ```yaml
   - name: Download artifacts
     uses: actions/download-artifact@v4
     with:
       path: /tmp/artifacts
   ```

2. **Load, Scan, and Push Images**
   ```yaml
   - name: Load, scan, and push images
     run: |
       # Load each permutation tar, scan with Trivy, push with SHA tags
       # (Implementation similar to existing publish job)
   ```

**Note:** This job can reuse the existing publish logic from `build-devcontainer.yml` but adapted for Docker actions.

## Required Changes to docker-bake.hcl

### Add CI Helper Target

Add to root `docker-bake.hcl` (or create one if it doesn't exist):

```hcl
target "ci-helper" {
  context    = "."
  dockerfile = ".github/ci/ci-runner.Dockerfile"
  platform   = ["linux/amd64"]
  tags       = ["ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/ci-helper:local"]
  labels = {
    "org.opencontainers.image.title"       = "CI Helper"
    "org.opencontainers.image.description" = "CI helper image with Docker CLI, buildx, devcontainers CLI, hadolint"
  }
}
```

**Alternative:** If root `docker-bake.hcl` doesn't exist, create it with just the CI helper target, or add the target to `.devcontainer/docker-bake.hcl` (less ideal but workable).

## Cache Strategy

### GitHub Actions Cache (Recommended)
- **Type:** `type=gha` (GitHub Actions cache backend)
- **Scope:** Include branch/ref name to avoid cross-branch cache pollution
- **Mode:** `mode=max` for cache-to to store all layers
- **Advantages:** No local disk bloat, automatic cleanup, shared across runners

### Local Cache (Fallback)
- **Type:** `type=local`
- **Directory:** `/tmp/.buildx-cache` (or configurable via env)
- **Cleanup:** Periodic `docker builder prune` in cleanup steps
- **Use Case:** When GHA cache quota is exhausted or for local testing

### Cache Scoping
- CI Helper: `ci-helper-${{ github.ref_name }}`
- Devcontainers: `devcontainer-${{ matrix.permutation }}-${{ github.ref_name }}`

## Metadata and Tagging

### CI Helper Tags
- `latest` (always)
- `sha-<short>` (commit SHA, short format)

### Devcontainer Tags
- `${{ matrix.permutation }}` (e.g., `gcc14-clang21`)
- `${{ matrix.permutation }}-sha-<short>` (commit SHA)
- `latest-${{ matrix.permutation }}` (only on main branch push)

### Labels
- `org.opencontainers.image.title`
- `org.opencontainers.image.description`
- `org.opencontainers.image.source`
- `org.opencontainers.image.revision`

## Avoiding docker.io Pulls

### Strategy
1. **Build Base Locally:** Ensure `base` target in `.devcontainer/docker-bake.hcl` builds locally first
2. **Use Local Tags:** Reference `BASE_TAG` variable pointing to locally built base
3. **Pull Policy:** Set `pull: false` in bake targets unless explicitly needed
4. **Registry Pinning:** If external bases are required, pin to GHCR mirrors or internal registry

### Implementation
```hcl
target "base" {
  # Builds base image locally, no pull
  tags = ["cpp-cpp-dev-base:local"]
}

target "devcontainer_gcc14_clang_qual" {
  inherits = ["_base"]
  # Uses local base tag, no docker.io pull
}
```

## Failure Hygiene

### Always-Run Cleanup
- `docker builder prune -f --filter until=24h`
- `docker image prune -f --filter until=24h`
- Remove temporary files (`/tmp/*.tar`, `/tmp/tag-*.txt`)

### Conditional Cleanup
- Aggressive cleanup only on main branch to preserve PR caches
- Use `if: always() && github.ref == 'refs/heads/main'` for heavy cleanup

### Timeout Protection
- Set `timeout-minutes: 60` for CI helper job
- Set `timeout-minutes: 120` for devcontainer build job

### Error Handling
- Use `|| true` for cleanup commands to avoid failing on missing resources
- Use `if-no-files-found: ignore` for artifact uploads

## Pitfalls and Recommendations

### 1. Bake Target Naming
- **Issue:** Matrix permutation names don't match bake target names exactly
- **Solution:** Use a mapping step (step 9 in Job 2) to convert permutation to target

### 2. Cache Scope Collisions
- **Issue:** Different branches sharing cache can cause stale builds
- **Solution:** Include `${{ github.ref_name }}` in cache scope

### 3. Metadata Action Output Format
- **Issue:** `docker/metadata-action` outputs tags as newline-separated string
- **Solution:** Use `set: *.tags=${{ steps.meta.outputs.tags }}` directly in bake-action

### 4. Self-Hosted Runner Docker Socket
- **Issue:** Buildx may not detect docker socket automatically
- **Solution:** Use `driver-opts: network=host` or ensure `DOCKER_HOST` is set

### 5. Artifact Size Limits
- **Issue:** Image tars can exceed GitHub Actions artifact limits (10GB)
- **Solution:** Only upload tars for PR builds; push directly to registry for main branch

### 6. Bake File Location
- **Issue:** CI helper target may not be in `.devcontainer/docker-bake.hcl`
- **Solution:** Create root `docker-bake.hcl` or add target to `.devcontainer/docker-bake.hcl`

### 7. QEMU Setup (Multi-Arch)
- **Issue:** If multi-arch builds are needed, QEMU setup is required
- **Solution:** Add `docker/setup-qemu-action@v3` before buildx setup (not needed for linux/amd64 only)

### 8. Buildx Driver Selection
- **Issue:** `docker` driver has limitations with advanced cache features
- **Solution:** Use `docker-container` driver for better cache isolation (requires `driver: docker-container` in setup-buildx-action)

## Migration Steps

1. **Create root `docker-bake.hcl`** with `ci-helper` target (or add to existing)
2. **Create new workflow file** with timestamp format `YYYYMMDDHHMMSS.<9-digit-nanos>.yml`
3. **Test CI helper build** in isolation first
4. **Test single devcontainer permutation** before enabling full matrix
5. **Validate cache behavior** (check cache hits in build logs)
6. **Monitor artifact uploads** (ensure tars are created correctly)
7. **Disable old workflows** after validation
8. **Clean up old workflow files** after successful migration

## Validation Checklist

- [ ] CI helper builds and pushes successfully
- [ ] CI helper image is available for devcontainer builds
- [ ] All 6 devcontainer permutations build successfully
- [ ] Cache is being used (check build logs for cache hits)
- [ ] Tags are correct (latest + SHA for helper, permutation + SHA for devcontainers)
- [ ] Artifacts upload correctly (for PR builds)
- [ ] Images push to GHCR (for main branch)
- [ ] Cleanup runs without errors
- [ ] Runner guard works correctly
- [ ] No docker.io pulls occur (check build logs)

## Example Workflow File Structure

```yaml
name: Build CI Helper and Devcontainers

on:
  push:
    branches: [main, modernization.20251118]
    paths:
      - '.github/ci/**'
      - '.devcontainer/**'
      - 'docker-bake.hcl'
      - '.github/workflows/*.yml'
  workflow_dispatch:

concurrency:
  group: ci-devcontainers-${{ github.ref }}-${{ github.event_name }}
  cancel-in-progress: true

env:
  DOCKER_BUILDKIT: 1
  BUILDX_NO_DEFAULT_LOAD: 1

jobs:
  build-ci-helper:
    # ... (as detailed above)

  build-devcontainers:
    needs: build-ci-helper
    # ... (as detailed above)

  publish-devcontainers:
    needs: build-devcontainers
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    # ... (optional, as detailed above)
```

## References

- [docker/bake-action@v6](https://github.com/docker/bake-action)
- [docker/metadata-action@v5](https://github.com/docker/metadata-action)
- [docker/setup-buildx-action@v3](https://github.com/docker/setup-buildx-action)
- [Docker Buildx Cache Backends](https://docs.docker.com/build/cache/backends/)
- [GitHub Actions Artifacts](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)
