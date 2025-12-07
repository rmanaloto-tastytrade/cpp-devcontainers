**Combined Workflow Shape**
- Filename: `20250205153000.000000000.yml` (replace with actual timestamp `YYYYMMDDHHMMSS.<9-digit-nanos>` when creating).
- Triggers: `workflow_dispatch`, `push` to main branches, optional `pull_request` with `paths` filter to Docker/devcontainer files.
- Concurrency: `group: ci-devcontainers-${{ github.ref }}-${{ github.event_name }}`, `cancel-in-progress: true`.

**Job 1: build-ci-helper**
- Runs-on: `[self-hosted, devcontainer-builder, c0802s4]`; `services` not needed (Docker socket available).
- Permissions: `contents: read`, `packages: write`, `id-token: write` (for GHCR OIDC), `actions: read`.
- Steps:
  1) `docker/setup-qemu-action@v3` (if multi-arch; otherwise skip).
  2) `docker/setup-buildx-action@v3` (driver docker-container, bake cache enabled).
  3) `docker/login-action@v3` with GHCR using `${{ github.actor }}` / `${{ secrets.GITHUB_TOKEN }}` (or OIDC—set `registry: ghcr.io`).
  4) `docker/metadata-action@v5`:
     - `images: ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/ci-helper`
     - `tags: type=sha,prefix=,suffix=,format=short\n type=raw,value=latest`.
  5) `docker/bake-action@v6` (or `build-push-action@v6` if single target) with `.devcontainer/docker-bake.hcl` (or dedicated `docker-bake.hcl` for helper):
     - `targets: ci-helper` (ensure target defined; else add in bake file).
     - `push: true`.
     - Cache: `cache-from: type=gha,scope=ci-helper` / `cache-to: type=gha,scope=ci-helper,mode=max` (or `type=registry` fallback).
  6) Optional: `actions/cache` for `.cache/buildx` if preferring local cache; clean after run.

**Job 2: build-devcontainers (needs: build-ci-helper)**
- Matrix: from `.devcontainer/docker-bake.hcl` (targets like `gcc14`, `gcc15`, `clang14`, `clang15`, `clang15-p2996`, etc.). Example:
  ```yaml
  strategy:
    fail-fast: false
    matrix:
      target: [gcc14, gcc15, clang14, clang15, clang15-p2996]
  ```
- Permissions: same as above.
- Steps:
  1) `docker/setup-qemu-action@v3` (if multi-arch).
  2) `docker/setup-buildx-action@v3`.
  3) `docker/login-action@v3` to GHCR.
  4) `docker/metadata-action@v5`:
     - `images: ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/${{ matrix.target }}`
     - `tags: type=sha,format=short\n type=raw,value=latest`.
  5) `docker/bake-action@v6` with `.devcontainer/docker-bake.hcl`:
     - `targets: ${{ matrix.target }}`
     - `push: true`
     - `set: |
         *.tags=${{ steps.meta.outputs.tags }}
         *.labels=${{ steps.meta.outputs.labels }}`
     - Cache: `cache-from: type=gha,scope=devcontainer-${{ matrix.target }}` / `cache-to: type=gha,scope=devcontainer-${{ matrix.target }},mode=max`.
  6) Optional artifact upload of bake summary: `path: buildx-bake.json` if using `--print` or `--metadata-file`.

**Cache & Pull Hygiene**
- Prefer `cache-to/from` type `gha` to avoid local disk bloat on self-hosted. If local disk cache is required, add periodic cleanup (cron or concluding step `docker builder prune -f --filter until=24h`).
- Avoid docker.io pulls: ensure base images are built via bake (targets in `docker-bake.hcl` referencing local stages). For external bases, pin to GHCR or internal registry; use `pull: false` unless explicit.
- Use `--set` or bake `variables` to reference the freshly built `ci-helper` image as a base for downstream if needed.

**Runner Cleanup / Failure Hygiene**
- Final steps (always run): `docker logout ghcr.io`; `docker system df`; optional `docker buildx du`; `docker builder prune -f --filter until=24h` guarded with `if: always() && github.ref == 'refs/heads/main'` to avoid wiping caches mid-PR.
- Make jobs `fail-fast: false` for matrix to keep other targets building.
- Add `timeout-minutes` (e.g., 60 per job) to prevent hung builds.

**Permissions & Env**
- `env` at workflow level: `DOCKER_BUILDKIT: 1`, `BUILDX_NO_DEFAULT_LOAD=1`.
- Secrets: rely on `GITHUB_TOKEN` for GHCR; if using PAT, set `REGISTRY_USER/REGISTRY_TOKEN`.
- Set `pull_request` jobs to `push: false` (build only) if you want to avoid publishing from forks; guard with `if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository`.

**Key Pitfalls to Avoid**
- Ensure `docker-bake.hcl` contains a `ci-helper` target; if not, add one referencing the helper Dockerfile.
- Keep metadata from `docker/metadata-action` wired into bake (`*.tags`, `*.labels`).
- Don’t run `docker/build-push-action` and `docker/bake-action` concurrently on same builder without isolating cache scopes.
- Confirm `self-hosted` runner has `docker` group membership; otherwise use `docker/setup-docker-action@v4`/`setup-compose-action` only if daemon missing (unlikely here).
- Avoid GHA artifact bloat; only upload minimal logs/metadata.

**Suggested Layout (condensed YAML sketch)**
```yaml
name: CI Devcontainers
on:
  workflow_dispatch:
  push:
    branches: [main]
    paths: [.devcontainer/**, docker-bake.hcl, .github/workflows/**]
  pull_request:
    paths: [.devcontainer/**, docker-bake.hcl]

concurrency:
  group: ci-devcontainers-${{ github.ref }}-${{ github.event_name }}
  cancel-in-progress: true

jobs:
  build-ci-helper:
    runs-on: [self-hosted, devcontainer-builder, c0802s4]
    permissions: {contents: read, packages: write, id-token: write}
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with: {registry: ghcr.io, username: ${{ github.actor }}, password: ${{ secrets.GITHUB_TOKEN }}}
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/ci-helper
          tags: |
            type=sha,format=short
            type=raw,value=latest
      - uses: docker/bake-action@v6
        with:
          files: .devcontainer/docker-bake.hcl
          targets: ci-helper
          push: true
          set: |
            *.tags=${{ steps.meta.outputs.tags }}
            *.labels=${{ steps.meta.outputs.labels }}
          cache-from: type=gha,scope=ci-helper
          cache-to: type=gha,scope=ci-helper,mode=max
      - if: always()
        run: docker builder prune -f --filter until=24h

  build-devcontainers:
    needs: build-ci-helper
    runs-on: [self-hosted, devcontainer-builder, c0802s4]
    strategy:
      fail-fast: false
      matrix:
        target: [gcc14, gcc15, clang14, clang15, clang15-p2996]
    permissions: {contents: read, packages: write, id-token: write}
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with: {registry: ghcr.io, username: ${{ github.actor }}, password: ${{ secrets.GITHUB_TOKEN }}}
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/${{ matrix.target }}
          tags: |
            type=sha,format=short
            type=raw,value=latest
      - uses: docker/bake-action@v6
        with:
          files: .devcontainer/docker-bake.hcl
          targets: ${{ matrix.target }}
          push: ${{ github.event_name == 'push' }}
          set: |
            *.tags=${{ steps.meta.outputs.tags }}
            *.labels=${{ steps.meta.outputs.labels }}
          cache-from: type=gha,scope=devcontainer-${{ matrix.target }}
          cache-to: type=gha,scope=devcontainer-${{ matrix.target }},mode=max
      - if: always()
        run: docker builder prune -f --filter until=24h
```

If you want, I can draft the actual workflow YAML with the correct timestamped filename and align the `docker-bake.hcl` targets for the helper.