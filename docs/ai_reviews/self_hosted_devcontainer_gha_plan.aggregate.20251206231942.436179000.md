# Aggregate Review: Self-Hosted Devcontainer (linux/amd64, latest round)

Sources (2025-12-06):
- claude.self_hosted_devcontainer_gha_plan_review.20251206231332.894350000.md
- gemini.self_hosted_devcontainer_gha_plan_review.20251206231508.101885000.md
- dockerai.self_hosted_devcontainer_gha_plan_review.20251206231636.324174000.md
- codex.self_hosted_devcontainer_gha_plan_review.20251206221846.414927000.md (last Codex run)

## Converging Issues
- **Push timing**: SBOM/Trivy run after pushing in build job; vulnerable images could hit GHCR before scan. Move scans before any push.
- **Duplicate builds**: Publish job rebuilds/pushes after build job already pushed; doubles work, risks inconsistency. Prefer build→validate→scan, then promote/re-tag without rebuild (and gate push until all succeed).
- **Cache scope & validate**: Validate runs with `--no-cache` (good) but build uses cache; consider isolating cache scope (per ref/branch) to avoid PR cache poisoning; actions/cache on /tmp/.buildx-cache is redundant with buildx gha cache.
- **Base/image pinning**: Ubuntu now has a digest, but other upstream downloads/apt keys still unpinned; need rotation policy.
- **Publish gating**: Matrix build still pushes in build job (main) and again in publish; tag promotion not gated on all-green matrix; tag maps remain per-job artifacts (no consolidated manifest).
- **Rollback/operational gaps**: No documented rollback or GHCR retention; long-running builds not canceled (`cancel-in-progress: false`); could block urgent fixes.
- **Deferred security**: Signing/provenance and fuller vuln scans (secrets/config), secrets-handling docs still pending (per plan).
- **Runner hygiene**: No cleanup/idempotence on failure; risk of dirty caches/images between runs; timeout 120m may be tight if double-build remains.

## Suggested Fixes (short list)
1) Reorder build job: build → SBOM → Trivy (blocking) → push; or build-only, then promote in publish.
2) Change publish job to promote/re-tag after all build jobs succeed; avoid rebuild/push in build job (set PUSH_IMAGES=0 there) to prevent partial publishes.
3) Scope buildx cache by branch/ref and drop actions/cache on /tmp/.buildx-cache if using `type=gha`; keep validate `--no-cache`.
4) Pin remaining critical downloads/apt keys; document digest refresh cadence.
5) Add rollback/retention notes to workflow docs; consider `cancel-in-progress` true for non-main if desired.
6) Track deferred security items (signing/provenance, expanded scans, secrets docs) as follow-up once builds are stable.***
