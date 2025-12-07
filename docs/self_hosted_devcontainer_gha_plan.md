# Self-Hosted Devcontainer Builds via GitHub Actions

Purpose: move devcontainer builds to the existing self-hosted runner pipeline, triggered by commits, using the project’s automation (no manual docker commands). This documents the current state and the plan to implement it.

## Current State (from `origin/main`)
- `README.md`: documents how to install and register a self-hosted runner with labels `self-hosted` and `devcontainer-builder`; states pushes to `main` trigger a devcontainer build.
- `.github/workflows/README.md`: describes `build-devcontainer.yml` that builds `.devcontainer/Dockerfile` on the `self-hosted`/`devcontainer-builder` runner, logging in to GHCR and pushing `latest` and `${{ github.sha }}` tags.
- `.github/workflows/build-devcontainer.yml` (present on `origin/main`, not in the working tree): single-image build, no permutation matrix, builds directly from `.devcontainer/Dockerfile`.
- `.devcontainer/devcontainer.json`: consumes an image via `DEVCONTAINER_IMAGE` env var; does not currently point to a GHCR tag produced by the workflow and does not distinguish permutations.
- Local automation/scripts (matrix/deploy) handle permutations and validation but are not wired into GitHub Actions.

## Gaps
- The self-hosted workflow builds only one image (no gcc/clang permutations) and bypasses the project’s bake/scripts, so validations are not enforced.
- The workflow file on `origin/main` is missing from this branch; devcontainer.json has no documented mapping to the GHCR images the workflow would produce.
- No automated path ties a commit to rebuilt, validated devcontainer images that the repo can consume by default.

## Plan (top priority)
1) Restore and extend `build-devcontainer.yml`  
   - Bring the workflow from `origin/main` into the working tree (inspect/diff before changes); enforce runner label/name guard to avoid unintended/costly hosts.  
   - Convert it to call a scriptified entry point (e.g., `scripts/ci/build_devcontainers_ci.sh`) that wraps `docker buildx bake` for all supported permutations, reusing the same args/validation hooks as our local automation.  
   - Run on self-hosted runner labels `self-hosted` + `devcontainer-builder`; keep GHCR login with `GITHUB_TOKEN`. Add concurrency grouping so tag pushes cannot race.
   - Emit tagged images per permutation with unambiguous names (e.g., `devcontainer:gcc15-clangp2996`, `devcontainer:gcc15-clang22`, plus SHA+permutation tags). Avoid a single `latest`; if needed, use `latest-<perm>` after all permutations succeed.

2) Add CI-friendly build/validate script  
   - New script drives the bake targets for all permutations using the same env vars (CLANG_VARIANT, GCC_VERSION, DEVCONTAINER_CXX_STD, etc.) and enables the existing validations. Validate required env/schema upfront to prevent drift.  
   - Include robust smoke per image: clang/gcc versions, libc++ availability, vcpkg root, mold, CMake preset/toolchain check (e.g., `cmake -P` or configure a tiny project).  
   - Keep the script self-contained so Actions only calls one entry point; publish logs/digests as artifacts; enable buildx cache (registry or local dir) for speed; check runner readiness (buildx/QEMU, disk space) before baking.  
   - Run `docker buildx bake --print/--check` and `docker buildx bake validate` (new validate group) before any push/build; fail fast on stage-level validation errors.

3) Wire devcontainer consumption to GHCR outputs  
   - Document default `DEVCONTAINER_IMAGE` values for each permutation (GHCR tags) and add examples to `.devcontainer/devcontainer.json` docs/comments.  
   - Provide an env file or generated artifact mapping permutation -> GHCR tag so local `devcontainer up` can pick the correct tag without manual edits; keep it refreshed by CI.

4) Documentation updates  
   - Update `README.md` and `.github/workflows/README.md` to describe the multi-permutation self-hosted workflow, triggers (push to main/PR), required runner labels, and the new CI script.  
   - Add a short “how to pull/use the GHCR devcontainer image” section pointing to the tags produced in step 3.  
   - Clarify PR behavior: PRs build/validate without pushing; main builds push. Document rollback procedure and GHCR retention/cleanup.

5) Validation and rollout  
   - Dry-run the workflow on the self-hosted runner (workflow_dispatch) to verify bake targets, tagging, and validation.  
   - Ensure the runner has the needed Docker Buildx/QEMU bits and access to GHCR.  
   - After a green run, update any downstream docs that reference manual container builds to point to the new automated pipeline.  
   - Add base-image pinning (digests), SBOM/provenance, and a vulnerability scan/attestation step; document or implement GHCR pruning and rollback steps.

## Latest updates (working tree)
- Workflow now writes per-permutation manifests with `image_id` digests; publish validates manifest entries against loaded images before scanning/pushing. Consolidated manifest/tag-map artifacts are produced as JSONL + plain text.  
- Cache scopes are salted by commit (`GITHUB_SHA`) to avoid cross-branch/main reuse; PR builds disable cache entirely. Build job now prunes Docker/Buildx even on failure.  
- Scanner images pinned by digest (hadolint 2.12.0, Trivy 0.54.1) and Trivy scans include MEDIUM/HIGH/CRITICAL severities.  
- New rollback/retention automation under `scripts/ci/ghcr_devcontainer_rollback.sh` and `scripts/ci/ghcr_devcontainer_prune.sh` (dry-run by default).  
- Security/runner guidance captured in `docs/runner_security.md`; signing/provenance is still a follow-up item to add after the workflow stabilizes.

## Constraints / Near-term scope
- Architecture: focus on linux/amd64 (EPYC/Zen3 remote host); no multi-arch builds for now.
- PRs: remain on self-hosted runner; set workflow timeout to 120 minutes.
- Security hardening (signing/provenance, expanded vuln scans, secrets handling docs) will be handled after the devcontainers build/run reliably; keep it listed as follow-up work.

See `docs/ai_agent_cli_usage.md` for running Codex/Claude/Gemini CLIs non-interactively to review this plan.
