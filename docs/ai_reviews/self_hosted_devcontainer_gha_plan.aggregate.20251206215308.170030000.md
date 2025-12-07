# Aggregate Review: Self-Hosted Devcontainer GHA Plan

Sources:
- codex.self_hosted_devcontainer_gha_plan_review.20251206215035.743458000.md
- claude.self_hosted_devcontainer_gha_plan_review.20251206215108.036666000.md
- gemini.self_hosted_devcontainer_gha_plan_review.20251206215159.198588000.md

## Converging Criticals
- Restore/analyze the missing `build-devcontainer.yml` from `origin/main` before extending; align triggers/permissions.
- Define explicit permutation matrix and tagging (avoid single `latest`, prevent tag races; use SHA+permutation, optionally `latest-<perm>`).
- Guard publishing: push only on main; PRs build/validate without push; protect secrets on forks.
- Strengthen validation: real smoke (CMake preset/toolchain, vcpkg path, mold, clang/gcc versions, libc++), fail-before-push.
- Runner safety: enforce correct self-hosted runner/labels and cost-protection check; validate buildx/QEMU/docker cache readiness.
- Reproducibility: pin base image digests and bake inputs; document rollback strategy and GHCR cleanup/retention.

## Additional Gaps/Optimizations
- Add buildx cache (registry/dir) for speed; add observability (digests/log artifacts, alerts).
- Clarify permutation naming so tags aren’t ambiguous (clang vs gcc images); avoid dual-toolchain ambiguity.
- Add env mapping/artifact so devcontainer consumers get correct GHCR tag; keep it updated from CI.
- Consider security scanning/attestation (Trivy/Scout/Cosign) before publish.
- Validate env var schema in CI script to prevent drift; run pre-commit checks before expensive builds.

## Action Items (short list)
1) Bring `build-devcontainer.yml` into working tree; gate pushes to main; add concurrency group and matrix with explicit permutations/tags.  
2) Add CI entry script wrapping bake with env validation, buildx cache, runner readiness checks, and robust smoke tests; publish digests/logs.  
3) Pin base images, define rollback and GHCR retention; add vulnerability scan step (or document deferral).  
4) Produce/commit or artifact an env/tag map for devcontainer consumers; document usage in README/workflow docs.  
5) Add runner/cost guard and clarify PR vs main behavior (build-only vs build+push).  
