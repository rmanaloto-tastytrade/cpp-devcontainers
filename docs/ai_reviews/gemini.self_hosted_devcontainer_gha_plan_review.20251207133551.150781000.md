Here are the steps to resolve the GitHub Actions failure and enforce your image pull policy:

*   **Use Fully Qualified Image Names (FQINs):**
    *   In `.devcontainer/docker-bake.hcl`, explicitly define tags with your GHCR namespace for all images intended for registry use (e.g., `ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/cpp-cpp-dev-base:latest`). This prevents BuildKit from defaulting to Docker Hub.
    *   For the base image used only within the CI job, use a job-specific tag like `cpp-dev-base:ci-build`.

*   **Isolate Base and Final Image Builds in Bake:**
    *   Define two separate targets in `docker-bake.hcl`: one for the base image (`base`) and one for the final devcontainer image (`app`).
    *   In the `app` target, ensure it does not pull the base image by referencing the locally built version. Use `context.source` or ensure the `FROM` instruction in the `app` Dockerfile uses the exact tag built by the `base` target.
    *   Use `ARG` in the final `Dockerfile` for the base image (`ARG BASE_IMAGE=...`) and pass the specific tag from the bake target via the `args` attribute.

*   **Control Workflow Execution:**
    *   In your GitHub Actions workflow, use `docker/bake-action` with `load: true` and `push: false` for the base image target. This builds the base image and loads it into the runner's local Docker context without pushing.
    *   For the final image target, the subsequent `bake` command will find the base image in the local context and will not attempt to pull it.

*   **Implement a Robust Cache Strategy:**
    *   Set up GHCR as your primary cache layer in `docker-bake.hcl`. For each target, define `cache-from` and `cache-to`:
        ```hcl
        cache-from = ["type=registry,ref=ghcr.io/rmanaloto-tastytrade/cpp-devcontainers:buildcache"]
        cache-to   = ["type=registry,ref=ghcr.io/rmanaloto-tastytrade/cpp-devcontainers:buildcache,mode=max"]
        ```
    *   Only `push` the cache (`mode=max`) on successful builds from your main branch to keep it clean.

*   **Add Validation Guards:**
    *   Set `pull = false` in the `docker/bake-action` step for targets that should only use local context.
    *   Add a workflow step to grep the build logs for `docker.io` pull attempts and fail the job if any are found, preventing accidental fallbacks.
        ```yaml
        - name: Check for Docker Hub fallbacks
          run: |
            if grep -q "docker.io/library/cpp-cpp-dev-base" build.log; then
              echo "Error: Fallback to Docker Hub detected!"
              exit 1
            fi
        ```
