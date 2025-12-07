# Workflows Documentation

This folder contains GitHub Actions workflows for the SlotMap project. The workflows automate tasks such as building the devcontainer images and running CI.

## build-devcontainer.yml

Builds all devcontainer permutations on a self-hosted runner (labels: `self-hosted`, `devcontainer-builder`, `c0802s4-000`) using `docker buildx bake` via `scripts/ci/build_devcontainers_ci.sh`.

- Matrix: gcc14/gcc15 × clang21/clang22/clangp2996.
- Runner guard to avoid unintended/costly hosts.
- Preflight devcontainer/bake validation (`check_docker_bake.sh`, `check_devcontainer_config.sh`).
- Buildx cache via `type=gha` salted by commit (`CACHE_SCOPE_SALT` -> `GITHUB_SHA`); PR builds disable cache.
- Runs `bake --print/--check` and `bake validate` targets before building; build job uploads image tars/manifests; publish job validates manifests vs loaded images, then SBOM + Trivy scans (pinned digests) before pushing permutation + SHA tags.
- Hadolint/Trivy pinned by digest; base image pinned by digest; runner cleanup after build/publish; artifacts (tag maps, manifests, SBOMs) uploaded.

### Trigger

- `push` to `main`
- `pull_request` to `main` (build-only)
- `workflow_dispatch`

### Rollback / retention
- To roll back a bad push: use `scripts/ci/ghcr_devcontainer_rollback.sh` (pulls `<sha>-<perm>`, retags `<perm>` and optional new `<sha>-<perm>`, and pushes).
- GHCR retention: use `scripts/ci/ghcr_devcontainer_prune.sh` (dry-run by default; set `DELETE=1`) to prune older SHA tags per permutation. See `docs/runner_security.md` for runner/secret hygiene notes.

## ci.yml

Builds and tests the codebase on supported platforms/runtimes.

## coverage.yml

Runs coverage collection and reporting for the codebase.

## devcontainer-lint.yml

Validates devcontainer configuration and linting rules.

## hardcoded-guard.yml

Guards against reintroducing hardcoded host/user/port strings.
