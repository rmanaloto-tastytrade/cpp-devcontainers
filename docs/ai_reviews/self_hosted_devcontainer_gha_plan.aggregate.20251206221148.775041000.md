# Aggregate Review: Self-Hosted Devcontainer Validations (Round 2)

Sources (2025-12-06):
- codex.self_hosted_devcontainer_gha_plan_review.20251206220653.820294000.md
- claude.self_hosted_devcontainer_gha_plan_review.20251206220845.386111000.md
- gemini.self_hosted_devcontainer_gha_plan_review.20251206221038.417555000.md

## Converging Must-Fix Validation Gaps
- Stage-level asserts are weak/missing: downloads lack sha/fingerprint checks; apt repos (Kitware/LLVM) and base image digests not pinned; fallback installs (gcc15/p2996) can silently yield empty dirs.
- No bake-driven validate targets: permutations build, but there is no `validate` group or check stages to gate pushes. Validations only happen post-build, not bound to bake.
- Compiler correctness: no compile/link/run smoke per permutation (libc++/libstdc++), no enforcement that only expected compilers are present.
- Tool stages (mold, iwyu, gh-cli, awscli, pixi, uv/ruff, mermaid, mrdocs, jq, ripgrep, ccache/sccache, valgrind) lack version/assert checks and SHA validation of archives/installers.
- Merge/final stage: no checks that disabled tools are absent, PATH order is correct, /opt/stage is emptied, and vcpkg cache/symlink correctness is enforced.
- PR/main gating: validations not run as bake targets before push; GHCR pushes could happen without validation.

## Recommended Embedding (docker-bake/Dockerfile)
- Add `check_<stage>` stages in Dockerfile (`FROM <stage> AS check_<stage>`) that run fast asserts: version greps, sha files, path existence/absence, symlink targets, and small compile+run for compilers (with libc++/libstdc++).
- In docker-bake.hcl, define `validate_<stage>` targets inheriting the build target but overriding `target="check_<stage>"` and `output=["type=cacheonly"]`; create a `group "validate"` covering base + all permutation targets.
- Add a bake function/flag (e.g., `--set *.output=type=cacheonly`) for validate runs. Run `docker buildx bake validate` before any push; fail the workflow on any validate error.
- In CI script, run bake validate before bake build/push; keep post-build in-container verification (scripts/verify_devcontainer.sh) for an extra layer.

## Stage-Specific Validation Examples
- Base: fingerprint-check apt keys, assert gcc/g++ alternatives match GCC_VERSION, require /opt/llvm-packages-*.txt, check cmake/ninja versions, pin base image digest.
- Compiler permutations: ensure `/opt/clang-p2996/bin/clang++-p2996` or `/opt/gcc-15/bin/g++-15` exists only when enabled; ensure unexpected compilers absent; compile+run hello with libc++/libstdc++ and correct -std (c++26).
- Tool stages: enforce SHA256 for downloaded archives (mold, gh-cli, awscli, pixi/uv/ruff, mermaid/node, mrdocs, jq, ripgrep, ccache/sccache, valgrind); run `--version` checks; for iwyu validate linkage to correct LLVM; for mold check both `mold` and `ld.mold` symlinks.
- Merge/final: assert /opt/stage empty post-copy, PATH ordering sane (ccache/sccache ahead of compilers), disabled tools absent, /opt/vcpkg symlinked to cache, cache dirs owned by user.

## Actions to Apply Now
1) Add check stages + validate targets/group in Dockerfile/docker-bake.hcl; wire `buildx bake validate` into workflow before push.
2) Strengthen CI entry script to run validate group first, then build/push, plus an in-container smoke that compiles/links with expected stdlib.
3) Add SHA/fingerprint pins for all downloads/apt keys and base image digests; fail on missing/extra compilers or empty fallback dirs.
4) Publish validation logs/digests as artifacts; document the validate flow in the plan and workflow README.
