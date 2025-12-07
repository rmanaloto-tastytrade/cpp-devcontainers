Of course. Here is a detailed plan for consolidating your GitHub Actions workflows.

First, I will analyze the existing workflows and the Docker Bake configuration to ensure the new, unified workflow correctly integrates all build targets and logic.
Great, I have the file list. I will now read `build-devcontainer.yml`, `publish-ci-helper.yml`, and `.devcontainer/docker-bake.hcl` to understand the current build logic and configurations.
Okay, I've reviewed the `build-devcontainer.yml` and its manual Docker build process. It's a prime candidate for `docker/bake-action`. I'll now examine `publish-ci-helper.yml` and `.devcontainer/docker-bake.hcl` to complete my analysis.
Read `publish-ci-helper.yml`: builds and pushes the `ci-helper` image. Now reading `.devcontainer/docker-bake.hcl` to understand the build configuration, then I'll create the plan.
Analysis of the current setup is complete. The existing workflows are complex and can be greatly simplified. `build-devcontainer.yml` manually orchestrates a build-then-publish flow using artifacts, while `publish-ci-helper.yml` handles a simple Docker build. The `docker-bake.hcl` file is well-structured for multi-stage builds but is only used by a script within the workflow, not by the `docker/bake-action` directly.

The migration will consolidate this into one efficient workflow using official Docker actions, with a single `docker-bake.hcl` file as the source of truth for all builds.

Here is the detailed migration plan:

### Plan to Consolidate Docker Image Workflows

This plan will merge `publish-ci-helper.yml` and `build-devcontainer.yml` into a single, efficient workflow file.

**1. Unify Build Definitions in `docker-bake.hcl`**

To manage all builds from a single file, we will first add a target for the `ci-helper` image within `.devcontainer/docker-bake.hcl`. This makes the bake file the definitive source for all image definitions.

**Action:** Add the following `target` and `group` to `.devcontainer/docker-bake.hcl`.

```hcl
target "ci-helper" {
  context    = "."
  dockerfile = ".github/ci/ci-runner.Dockerfile"
  # Tags are applied dynamically by the workflow
}

group "ci-helper" {
  targets = ["ci-helper"]
}
```

**2. Create the New Unified Workflow**

A single workflow, `.github/workflows/20251207120000.000000000.yml`, will replace the two old ones. It will contain two jobs that run sequentially:

*   **`build-and-push-helper`**: Builds and pushes the `ci-helper` image.
*   **`build-and-push-devcontainers`**: Builds and pushes the devcontainer matrix after the helper is available.

This approach ensures the `devcontainer` builds can rely on a freshly published `ci-helper` image if needed, while also benefiting from a warm build cache.

**3. Workflow Structure and Key Actions**

Below is the recommended structure for the new workflow.

*   **Workflow Name**: `Consolidated CI Build`
*   **File**: `.github/workflows/20251207120000.000000000.yml`
*   **Jobs**:

    *   **`build-and-push-helper`**:
        *   **Depends on**: Nothing.
        *   **Runner**: `[self-hosted, devcontainer-builder, c0802s4]`
        *   **Steps**:
            1.  `actions/checkout@v4`
            2.  `docker/login-action@v3`: Log in to GHCR.
            3.  `docker/setup-qemu-action@v3`: For multi-platform support (if needed).
            4.  `docker/setup-buildx-action@v3`: To set up the builder instance.
            5.  `docker/metadata-action@v5`: To generate tags for the `ci-helper` (`latest` and git `sha`).
            6.  `docker/bake-action@v5`:
                *   **`targets`**: `ci-helper`
                *   **`files`**: `./.devcontainer/docker-bake.hcl`
                *   **`push`**: `true`
                *   **`set`**: Injects the tags from the metadata action.

    *   **`build-and-push-devcontainers`**:
        *   **Depends on**: `build-and-push-helper`
        *   **Runner**: `[self-hosted, devcontainer-builder, c0802s4]`
        *   **Strategy Matrix**: The matrix will correspond to the build targets in the `docker-bake.hcl` file's `matrix` group.
            ```yaml
            strategy:
              fail-fast: false
              matrix:
                target:
                  - devcontainer_gcc14_clang_qual
                  - devcontainer_gcc14_clang_dev
                  - devcontainer_gcc14_clangp2996
                  - devcontainer_gcc15_clang_qual
                  - devcontainer_gcc15_clang_dev
                  - devcontainer_gcc15_clangp2996
            ```
        *   **Steps**:
            1.  `actions/checkout@v4`
            2.  `docker/login-action@v3`
            3.  `docker/setup-qemu-action@v3`
            4.  `docker/setup-buildx-action@v3`
            5.  `docker/metadata-action@v5`: To generate a supplementary tag based on git `sha` for each matrix image, providing better traceability.
            6.  `docker/bake-action@v5`:
                *   **`targets`**: `${{ matrix.target }}`
                *   **`files`**: `./.devcontainer/docker-bake.hcl`
                *   **`push`**: `true`
                *   **`set`**: Injects the supplementary SHA tag.

**4. Caching Strategy**

*   **Method**: Use Buildx's `local` cache. It is the most performant option for self-hosted runners as it avoids the network latency and size limitations of the `gha` cache.
*   **Implementation**: Configure the `docker/setup-buildx-action` step to use a persistent on-runner cache directory (e.g., `/tmp/.buildx-cache`). This cache will be shared between jobs on the same runner, dramatically speeding up subsequent builds.

**5. Self-Hosted Runner Hygiene**

*   **Post-Job Cleanup**: Each job will include a final step with `if: always()` to prune the Docker build cache and any dangling images (`docker builder prune -af && docker image prune -af`). This is critical to prevent the runner's disk from filling up over time.
*   **Failure Handling**: By simplifying the workflow to a direct `bake-and-push` model, we eliminate the primary failure point of the old system: the manual transfer and loading of tarball artifacts. If a bake fails, the logs will point directly to the Docker build error.

**6. Pitfalls to Avoid**

*   **Not Unifying the Bake File**: Avoid defining the `ci-helper` build inline in the workflow. Adding it to the HCL file centralizes all build logic.
*   **Using `gha` Cache**: On a dedicated self-hosted runner, the `local` cache is superior. The `gha` cache is better suited for ephemeral GitHub-hosted runners.
*   **Forgetting Cleanup**: Skipping the cleanup step *will* eventually cause runner disk space exhaustion.

This plan simplifies the CI/CD process, making it more robust, faster, and easier to maintain by embracing the intended use of the official Docker actions.

I will now proceed with the implementation of this plan, starting with modifying the `docker-bake.hcl` file.
