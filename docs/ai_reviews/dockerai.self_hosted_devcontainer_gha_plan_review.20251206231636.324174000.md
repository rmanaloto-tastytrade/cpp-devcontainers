Can I call filesystem?
Details: {
  "max_size_kb": 1024,
  "operation": "read",
  "path": "docs/self_hosted_devcontainer_gha_plan.md"
}
Here is a concise, actionable review of the current self-hosted devcontainer build/validation setup for linux/amd64 (EPYC/Zen3) based on the plan:

---

### 1. Validate Stage/Targets
- **Gap:** Current workflow builds only a single image, no permutations or bake targets.
- **Action:** Implement `docker buildx bake` with all permutations (gcc/clang variants, std versions) in a single CI script.  
- **Risk:** Without bake and validation, image correctness and consistency are not guaranteed.

### 2. Workflow Gating (120m timeout, PR self-hosted scope)
- **Gap:** PR builds do not push images; main builds do. Timeout is set to 120m, which is reasonable but tight for multiple permutations.
- **Action:** Ensure concurrency groups prevent race conditions on tag pushes. Monitor build times to avoid timeout failures.  
- **Risk:** Long builds may timeout; lack of concurrency control risks tag conflicts.

### 3. Caching/Tagging/Publish Gating
- **Gap:** No cache usage or tagging scheme beyond `latest` and SHA; no gating on successful validation before push.
- **Action:**  
  - Enable buildx cache (registry or local) to speed up builds.  
  - Use unambiguous tags per permutation (e.g., `gcc15-clangp2996`, SHA+perm). Avoid a single `latest` tag.  
  - Gate pushes on successful bake validation and smoke tests.  
- **Risk:** Inefficient builds, tag collisions, and pushing broken images.

### 4. Deferred Security Items
- **Gap:** Security hardening (signing, provenance, vulnerability scanning) deferred until builds are stable.
- **Action:** Track and schedule these as follow-up tasks post rollout.  
- **Risk:** Temporary exposure to unsigned or unscanned images; acceptable if documented and monitored.

---

### Summary of Immediate Actions
- Restore and extend the workflow to use `docker buildx bake` with all permutations and validations.
- Implement robust tagging and caching strategies.
- Enforce gating on validation success before pushing images.
- Monitor build duration to avoid 120m timeout issues.
- Document PR vs main build behavior clearly.
- Plan and track deferred security enhancements.

This will close the main gaps and reduce risks in the current self-hosted devcontainer build/validation setup.