# Aggregate Review: Self-Hosted Devcontainer (Post-changes Round)

Sources:
- codex.self_hosted_devcontainer_gha_plan_review.20251206221846.414927000.md
- claude.self_hosted_devcontainer_gha_plan_review.20251206223406.270983000.md
- gemini.self_hosted_devcontainer_gha_plan_review.20251206223207.676821000.md

## Remaining Gaps/Risks
- Base image digest not pinned (`ubuntu:24.04` tag still mutable); other downloads/apt repos not digest-locked.
- Tag gating: matrix jobs still push independently; no post-matrix gate or consolidated tag map; partial publishes remain possible.
- Self-hosted PR exposure: builds run on self-hosted for PRs from same repo but still risk on forks if condition missed; no timeout/permissions minimization.
- Validation caching: validate targets use cache; consider no-cache or dedicated cache scope to avoid skipping checks.
- Security: SBOM/scan added, but no signing/provenance (cosign/SLSA); vulnerability scan only on main; secrets handling for devcontainer users undocumented.
- Reproducibility/coverage: no multi-arch plan; devcontainer CLI build (not just validate) skipped; runtime/feature/SSH checks still minimal; permutation tags mutable without release semantics.
- Lint: Hadolint added; keep it enforced; bake --check still not used.

## Suggested Next Steps
1) Pin base image via digest arg and document refresh; consider pinning critical downloads/apt keys.  
2) Add post-matrix promotion job to push tags only if all permutations pass; emit merged tag-map artifact.  
3) Harden PR guard/permissions/timeouts on self-hosted; consider GH-hosted for PRs.  
4) Run validate with no-cache or isolated cache scope; optionally add `bake --check`.  
5) Add signing/provenance (cosign) and make vuln scan gating for main images; document secrets handling inside devcontainer.  
6) Evaluate multi-arch support; add devcontainer CLI build/feature checks and SSH/entrypoint runtime test if feasible.  
