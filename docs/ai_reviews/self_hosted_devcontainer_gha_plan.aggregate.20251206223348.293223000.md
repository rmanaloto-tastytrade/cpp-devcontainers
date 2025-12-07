# Aggregate Review: Self-Hosted Devcontainer (Post-validate Updates)

Sources (2025-12-06):
- claude.self_hosted_devcontainer_gha_plan_review.20251206223406.270983000.md
- gemini.self_hosted_devcontainer_gha_plan_review.20251206223207.676821000.md
- codex.self_hosted_devcontainer_gha_plan_review.20251206221846.414927000.md (latest successful Codex review)

## Remaining Critical Gaps
- **Base image pinning**: `ubuntu:24.04` not pinned to a digest; other upstream pulls (apt repos, node) not digest-locked. Supply-chain risk.
- **Validation linting**: No hadolint/ Dockerfile lint step; no bake `--check` gate beyond `--print`; validation uses cache (could mask failures).
- **Security gates**: SBOM/scout are best-effort only; no blocking vuln scan (Trivy/Grype) and no signing/provenance (cosign/SLSA). Secrets exposure risk on PRs to self-hosted runners is unmitigated.
- **Tag/publish gating**: Each matrix job still pushes independently; no “all green” gate for tag promotion and no consolidated tag map. `concurrency` serializes ref but doesn’t block partial publishes.
- **Cache strategy**: GHA cache + buildx cache config overlaps; registry/gha cache-to/from not fully standardized; validation may reuse cache (skip checks).
- **Reproducibility**: No multi-arch plan (arm64), no `--platform` matrix; permutation tags remain mutable without release semantics.
- **Runtime devcontainer checks**: No devcontainer CLI build/validate step; no feature/SSH/entrypoint validation beyond Dockerfile RUN checks.

## Action Items
1) Pin base images and key downloads to digests; document/automate digest refresh. Add `--pull` + digest args.
2) Add Dockerfile lint (hadolint) and bake `--check`; consider `--no-cache` for validate targets or `cache-to/from` scoping to avoid validation skipping.
3) Add blocking vuln scan (Trivy/Grype) before push; add SBOM/provenance/signing (cosign/SLSA) on main pushes. Restrict self-hosted PR runs (or use GH-hosted for PRs).
4) Gate tag promotion: push permutation/SHA only after validate passes; consider a post-matrix job to publish/promote and emit a single tag-map artifact. Keep `latest-*` off until all pass.
5) Standardize cache: prefer registry or buildx `type=gha` (no actions/cache duplication); ensure validation uses fresh layers.
6) Consider multi-arch (`linux/amd64,linux/arm64`) if runner/QEMU allows; document intent if staying amd64-only.
7) Add devcontainer CLI validation (`devcontainer validate/build`) and runtime checks for SSH feature/entrypoint; document secrets handling for users (SSH agent, gh auth, etc.).***
