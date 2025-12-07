### Gaps and Recommendations

Here is a concise, actionable review of the remaining gaps and risks in the devcontainer build plan.

**1. Artifact/Tag Mapping & Publish Gating**

*   **Gap:** The process of mapping build artifacts (tarballs) to image tags is manual and lacks a consolidated manifest. This increases the risk of tagging errors and makes rollbacks difficult.
*   **Recommendation:**
    *   Generate a `manifest.json` file during the build job. This file should contain an array of objects, each mapping a permutation to its tarball artifact name, final image tags (permutation + SHA), and the base image digest.
    *   The publish job should consume this `manifest.json` as the single source of truth for loading, scanning, and pushing images, preventing mismaps.

**2. Publish Gating & Rollback**

*   **Gap:** The plan lacks explicit quality gates before publishing. Rollback procedures are mentioned but not defined.
*   **Recommendation:**
    *   **Gating:** Implement a "gate" step in the publish job that blocks the push if Trivy scans detect critical/high vulnerabilities *or* if the SBOM generation fails. Use a dedicated, version-pinned Trivy configuration file for consistent results.
    *   **Rollback:** Define a formal rollback process. Pin the SHA of the *last known good* `manifest.json` as a workflow variable or tag. A rollback can be triggered by re-running the publish job with this pinned manifest SHA, ensuring a safe and predictable state restoration.

**3. Runner Hygiene & Retention**

*   **Gap:** While the runner is pruned post-publish, the plan does not address workspace state between runs or artifact retention policies. A persistent runner state is a security risk.
*   **Recommendation:**
    *   **Hygiene:** Ensure the self-hosted runner is configured to be ephemeral or, if not possible, add a pre-build step to the workflow that explicitly cleans the Docker workspace (`docker system prune -af --volumes`) to guarantee a pristine environment for every run and prevent state leakage.
    *   **Retention:** Define and document a retention policy for both GHCR images and workflow artifacts (e.g., 90 days for images, 30 days for artifacts). Automate this with a scheduled workflow using `actions/delete-package-versions` or a similar tool.

**4. Security Deferrals**

*   **Gap:** Image signing, provenance, and secrets documentation are deferred. These are critical for supply chain security.
*   **Recommendation:**
    *   Prioritize implementing image signing and provenance generation immediately after the core workflow is stable. Use Sigstore (`cosign`) to sign images and generate SLSA-compliant provenance attestations. This should be a non-negotiable step before considering the pipeline production-ready.
    *   Create a `SECRETS.md` document outlining the purpose, rotation policy, and access control for all secrets used in the workflow (e.g., `GITHUB_TOKEN`).

**5. Cache Poisoning Risk**

*   **Gap:** The primary risk lies in untrusted code from PRs poisoning the shared `buildx` cache. The current mitigations are good but can be hardened.
*   **Recommendation:**
    *   Strengthen cache isolation. In addition to scoping by `ref`, further isolate the GitHub Actions cache for PRs from the `main` branch cache. Use a distinct cache key prefix for `main` (e.g., `main-${{ hashFiles(...) }}`) versus PRs (e.g., `pr-${{ github.event.number }}-${{ hashFiles(...) }}`). This prevents a malicious PR from poisoning the cache used for production builds.
