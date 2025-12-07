# Aggregate Review: Self-Hosted Devcontainer (latest round)

Sources (2025-12-07):
- dockerai.self_hosted_devcontainer_gha_plan_review.20251207000008.826497000.md
- gemini.self_hosted_devcontainer_gha_plan_review.20251206235803.257793000.md
- codex.self_hosted_devcontainer_gha_plan_review.* (latest run timed out; previous codex review still relevant)

## Remaining Gaps / Risks
- Publish path: publish rebuilds/pushes; no reuse of build artifacts; tag map still per job.
- Cache strategy: buildx `type=gha` only; scope by ref; still no runner cleanup.
- Tooling pins: hadolint/trivy pinned; keep updating deliberately.
- Runner hygiene: missing cleanup step to prune images/cache between runs.
- Rollback/retention: still missing docs/procedure.
- Security deferrals: signing/provenance still missing; vuln scan limited to CRITICAL/HIGH; secrets handling not documented. Deferred but must be tracked.

## Suggested Fixes
1) Promotion/push: Either push in publish by rebuilding (set PUSH_IMAGES=1 there) or better, save/load the built images (e.g., `docker buildx bake ... --output type=docker` in build and `docker load` in publish) so publish can push what was validated. Pulling from GHCR won’t work until something pushes.
2) Cache: Drop actions/cache if using buildx `type=gha`; scope cache by ref. Keep validate no-cache.
3) Pin scanner/lint images (hadolint, trivy) to known tags.
4) Add runner cleanup (prune dangling images/cache) post-run.
5) Add rollback/retention notes to docs; outline how to re-tag a previous SHA.
6) Track deferred security items explicitly for follow-up (signing/provenance, expanded scans, secrets docs).***
