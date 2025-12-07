# Aggregate Review: Self-Hosted Devcontainer (artifact reuse + scans)

Sources (2025-12-07):
- codex.self_hosted_devcontainer_gha_plan_review.20251207002256.221049000.md
- gemini.self_hosted_devcontainer_gha_plan_review.20251207002256.221049000.md (latest)
- dockerai.self_hosted_devcontainer_gha_plan_review.20251207002420.963673000.md
- (Claude/Copilot/Cursor not available this run)

## Remaining Gaps / Risks
- Tag map/manifest: consolidated tag map exists but no digest validation; manifests not yet used to gate pushes.
- Publish gating: count check added, but no publish concurrency; reruns could overlap.
- Cache poisoning: buildx cache scoped by ref but shared across PR/main; consider separate scopes or disabling cache for PRs.
- Runner hygiene: cleanup covers docker prune + /tmp artifacts but not build job failures; no GHCR retention/rollback automation.
- Security deferrals: signing/provenance and secrets-handling docs still pending; scanners pinned by tag not digest; Trivy limited to CRITICAL/HIGH.

## Suggestions
1) Consolidate tag map: build uploads per-perm maps, publish downloads/merges, asserts completeness, and uploads a single manifest artifact.
2) Add matrix completeness check in publish: ensure expected perms count; fail fast if artifacts missing.
3) Split cache scope by event (refs/heads/main vs PR) or disable cache for PRs; keep validate no-cache.
4) Extend cleanup to remove /tmp/devcontainer-*.tar and other temp files.
5) Plan follow-up for signing/provenance and secrets/runner-hardening docs; optionally pin scanner images by digest.***
