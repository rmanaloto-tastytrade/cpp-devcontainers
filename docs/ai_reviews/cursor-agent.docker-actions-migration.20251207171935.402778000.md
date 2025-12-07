
Created a migration plan document. Summary:

## Summary

**Document Created:** `docs/ai_reviews/docker-actions-migration-plan.20251207180000.000000000.md`

### Structure

1. **Job 1: build-ci-helper**
   - Builds/pushes CI helper image using `docker/bake-action@v6`
   - Uses `docker/metadata-action@v5` for tags (latest + SHA)
   - GHA cache with branch-scoped keys
   - Always-run cleanup

2. **Job 2: build-devcontainers**
   - Matrix build for 6 permutations (gcc14/15 + clang21/22/p2996)
   - Depends on CI helper job
   - Uses bake targets from `.devcontainer/docker-bake.hcl`
   - Conditional push (only main branch)
   - Artifact uploads for PR builds

3. **Job 3: publish-devcontainers** (Optional)
   - Consolidates artifacts, scans, and pushes final tags
   - Only runs on main branch pushes

### Features

- Official Docker actions throughout (`docker/bake-action`, `docker/metadata-action`, etc.)
- GHA cache with branch-scoped keys to avoid cross-branch pollution
- Metadata/tagging: latest + SHA tags via `docker/metadata-action`
- Avoids docker.io pulls: builds base locally via bake
- Cleanup: always-run steps with conditional aggressive cleanup
- Self-hosted runner support: runner guards, docker socket handling

### Required Changes

1. Create root `docker-bake.hcl` with `ci-helper` target (or add to `.devcontainer/docker-bake.hcl`)
2. Map matrix permutations to bake target names (handled in workflow step)

### Pitfalls Addressed

- Cache scope collisions (branch-scoped)
- Metadata action output format (direct use in bake `set:`)
- Bake target naming mismatch (mapping step included)
- Artifact size limits (conditional upload strategy)
- Self-hosted runner docker socket (driver-opts included)

The plan includes step-by-step YAML, environment variables, permissions, and a validation checklist. Ready for implementation.
