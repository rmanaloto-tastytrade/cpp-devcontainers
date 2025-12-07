# Aggregate Review: Self-Hosted Devcontainer (artifact tar promotion)

Sources (2025-12-07):
- codex.self_hosted_devcontainer_gha_plan_review.20251207002256.221049000.md
- gemini.self_hosted_devcontainer_gha_plan_review.20251207002256.221049000.md
- dockerai.self_hosted_devcontainer_gha_plan_review.20251207002409.779649000.md

## Remaining Gaps / Risks
- Tag map/manifest: consolidated outputs exist but no digest validation; no consolidated artifact count check beyond expected loop.
- Publish gating: publish concurrency added, but reruns could overlap; still no automated GHCR retention/rollback.
- Cache poisoning: cache scoped by event/ref but shared on PR/main; consider separate scopes or disabling cache for PRs; validate cache usage.
- Runner hygiene: cleanup runs in publish; build failures may leave artifacts/caches; GHCR retention/rollback still manual.
- Security deferrals: signing/provenance and secrets handling docs still pending; scanners pinned by tag not digest; Trivy limited to CRITICAL/HIGH.

## Suggestions
1) Manifest/verification: generate a manifest (permutation -> tags -> digests) during build; publish should validate manifest completeness and digests before push; upload manifest artifact.
2) Publish gating: add a single gate that asserts all expected permutations are present before any push; add publish concurrency group; fail on missing artifacts.
3) Cache policy: split cache scopes for PR vs main or disable cache for PRs; keep validate no-cache; optionally clear cache on merge/close.
4) Runner hygiene/rollback: add cleanup on build failure; document automated rollback/retention or add a helper script to re-tag known-good SHA.
5) Security follow-up: add signing/provenance (cosign/attestations) and secrets/runner hardening doc; pin scanner images by digest; consider broader scan scope if needed.***
