# Aggregate Review: Self-Hosted Devcontainer Best-Practice Gaps (Round 3)

Sources (2025-12-06):
- codex.self_hosted_devcontainer_gha_plan_review.20251206220653.820294000.md
- codex.self_hosted_devcontainer_gha_plan_review.202512062215???.md (latest Docker best-practice pass)
- claude.self_hosted_devcontainer_gha_plan_review.20251206220845.386111000.md
- gemini.self_hosted_devcontainer_gha_plan_review.20251206221038.417555000.md

## Converging Critical Gaps vs Docker/devcontainer Best Practices
- **No bake-bound validation targets:** No `validate` group/targets; no bake `--print/--check` preflight. Images can push without stage-level asserts.
- **Tagging/publish safety:** Concurrency misuses `matrix.*` at workflow level; each job pushes permutation/`latest-<perm>` independently (no gate on full matrix success). Risk of partial publishes and tag races.
- **Reproducibility:** Base images and downloads not digest-pinned; no `--pull` on builds; some tools pinned to “latest” (awscli). Missing periodic refresh job.
- **Cache strategy:** Using tar cache under `/tmp/.buildx-cache` with actions/cache; best practice favors BuildKit registry or `type=gha` cache with inline metadata.
- **Security/compliance:** No SBOM/provenance attestations or vulnerability scan gate (e.g., docker/scout/trivy) before GHCR push.
- **Validation depth:** Current smoke is minimal; lacks compile/link/run per permutation (libc++/libstdc++), PATH/absent-unexpected compiler checks, feature/SSH/devcontainer CLI validation, runner readiness (disk/buildx/QEMU).
- **Devcontainer consumption:** No deterministic mapping from GHCR outputs to `devcontainer.json` defaults; consumers can’t auto-select CI-built permutations.

## Stage-Level Validation Gaps (examples)
- Base: no assert on gcc/g++ alternatives, cmake/ninja/make/git versions, apt key fingerprints; fallback gcc path not detected.
- Compiler stages: no checks for `/opt/clang-p2996` or `/opt/gcc-15` existence/absence; no compile/run with expected stdlib/-std.
- Tool stages (node/mermaid, mold, gh-cli, ccache/sccache, ripgrep, cppcheck, valgrind, python tools, pixi/uv/ruff, iwyu, mrdocs, jq, awscli): missing version/sha asserts and execution tests; mold/ld symlinks not verified.
- Merge/final: no checks that /opt/stage is emptied, disabled tools are absent, PATH ordering is correct, vcpkg symlink/cache layout enforced.

## Actions to Apply
1) Add `check_<stage>` targets in Dockerfile and `validate_<target>` targets + `group "validate"` in bake; run `docker buildx bake --print/--check` and `bake validate` before any build/push. Gate pushes on full matrix success; consolidate tag map.
2) Fix workflow concurrency (job-level group) and gate `latest-<perm>`/manifests on all permutations succeeding; add a merged permutation→tag artifact.
3) Pin base image/download digests; add `--pull`; add periodic refresh job; switch buildx cache to registry or `type=gha` with inline cache metadata.
4) Add SBOM/provenance attestation and vulnerability scan step before GHCR push.
5) Harden validation: compile/link/run with libc++/libstdc++, assert absence of unexpected compilers, verify PATH/order and cache/vcpkg symlink; optionally run devcontainer CLI `validate/build` and feature/SSH checks.
6) Publish a deterministic GHCR tag map and document how `devcontainer.json`/env selects the correct permutation by default.***
