# Docker Actions Migration Aggregate

Sources:
- docs/ai_reviews/codex.docker-actions-migration.20251207170804.016887000.md
- docs/ai_reviews/claude.docker-actions-migration.20251207171155.075684000.md
- docs/ai_reviews/gemini.docker-actions-migration.20251207171635.157132000.md
- docs/ai_reviews/docker-actions-migration-plan.20251207180000.000000000.md (cursor agent)

Key consensus:
- Use official Docker actions: setup-buildx, login, metadata, bake (v5/v6). QEMU only if multi-arch.
- Single workflow: job1 builds/pushes CI helper; job2 builds devcontainer matrix; optional publish step only on main.
- Keep a single docker-bake.hcl as the source of truth; add a ci-helper target there.
- Tagging via docker/metadata-action (sha + latest or permutation + sha + latest-permutation).
- Cache scopes per target/permutation; prefer gha cache for CI, prune routinely on self-hosted runners.
- Build base locally to avoid docker.io pulls; use bake set/load instead of manual docker commands.
- Fail-fast off for matrix; always-run cleanup; runner guard advised.
- Optional SBOM/provenance noted but deferred; artifacts only if needed (watch sizes).

Divergences / choices made:
- Cache backend: consensus split (gha vs local). Chosen gha with scoped keys; local fallback not wired.
- Optional publish job: cursor suggested; not implemented yet—can add later if artifact-driven publish is required.

Applied decisions in workflows:
- Added ci-helper target to .devcontainer/docker-bake.hcl.
- Replaced workflows with a single Build Devcontainers workflow: job `build-ci-helper` (metadata+bake push), job `build-devcontainers` (matrix bake, push on main). Base prebuild added to avoid docker.io pulls. Runner guard + cache scopes + cleanup included.
- Removed legacy publish-ci-helper workflow.
