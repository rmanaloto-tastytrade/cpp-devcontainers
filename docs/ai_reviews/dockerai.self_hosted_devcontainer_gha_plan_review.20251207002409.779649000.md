Here’s a concise review of your self-hosted devcontainer build/validation setup, focusing on the remaining gaps and risks:

### 1. Artifact/Tag Map Consolidation
- **Gap:** If image tars and tags aren’t tightly mapped, you risk pushing incorrect permutations or losing traceability.
- **Action:** Explicitly generate and persist a manifest (JSON/YAML) mapping each tar artifact to its intended tags/digests during build. Validate this manifest in publish before loading/pushing.

### 2. Publish Gating
- **Gap:** No explicit gating means images could be pushed even if validation (SBOM/Trivy) fails.
- **Action:** Enforce gating: only push images if all validation steps pass. Fail fast and block publish on any SBOM/Trivy error.

### 3. Runner Hygiene/Retention/Rollback
- **Gap:** Pruning after publish is good, but ephemeral artifacts or cache may persist if jobs fail or time out. Rollback is manual.
- **Action:** 
  - Automate runner cleanup on all job exit paths (success/failure/timeout).
  - Consider short-lived runners or ephemeral VMs for stronger isolation.
  - For rollback, maintain a manifest of previously pushed digests/tags and automate re-push on demand.

### 4. Security Deferrals (Signing/Provenance, Secrets Docs)
- **Gap:** No image signing/provenance; secrets documentation may be incomplete.
- **Action:** 
  - Integrate cosign or Docker Buildx attestation for image signing/provenance as soon as feasible.
  - Document all secrets usage, rotation, and storage practices in repo docs.

### 5. Cache Poisoning Risk
- **Gap:** Scoped buildx cache by ref is good, but if cache is not fully isolated per PR/branch, risk remains.
- **Action:** 
  - Ensure cache is strictly scoped to branch/PR and cleared on merge/close.
  - Validate cache integrity before use; consider disabling cache for untrusted PRs.

---

**Summary Table**

| Area                | Gap/Risk                        | Actionable Fix                                    |
|---------------------|---------------------------------|---------------------------------------------------|
| Artifact/Tag Map    | Mapping errors                  | Manifest for tar/tag mapping, validate on publish |
| Publish Gating      | Validation bypass               | Block push on SBOM/Trivy failure                  |
| Runner Hygiene      | Artifact/cache persistence      | Cleanup on all exits, ephemeral runners           |
| Rollback            | Manual, error-prone             | Manifest of digests/tags, automate re-push        |
| Security Deferrals  | No signing/provenance           | Add cosign/attestations, document secrets         |
| Cache Poisoning     | Incomplete isolation            | Strict cache scoping, validate/clear on merge     |

**Next Steps:**  
Prioritize manifest/tag mapping and publish gating for immediate reliability. Plan for signing/provenance and automate runner hygiene/rollback for long-term security and maintainability.

Sources:
- [https://docs.docker.com/build/ci/github-actions/multi-platform/](https://docs.docker.com/build/ci/github-actions/multi-platform/)
- [https://docs.docker.com/guides/gha/](https://docs.docker.com/guides/gha/)