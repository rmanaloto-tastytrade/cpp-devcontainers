# SlotMap Modernization

This repository hosts the policy-driven rewrite of Sergey Makeev's SlotMap container using C++23/26, a clang-21 toolchain, mold, and vcpkg for dependency management.

## Developer Workflow

1. **Bootstrap dependencies**  
   Use the provided devcontainer (`.devcontainer/`) on any Ubuntu 24.04 host or bootstrap the toolchain manually with clang-21, gcc-14 (from the Ubuntu Toolchain PPA), cmake 3.28+, ninja, mold, vcpkg, Graphviz, Doxygen, MRDocs, IWYU, and the productivity tooling we bundle (ccache, sccache, ripgrep).

2. **Configure & build**  
   ```bash
   cmake --preset clang-debug
   cmake --build --preset clang-debug
   ctest --preset clang-debug
   ```

3. **Documentation**  
   Documentation (MRDocs + Doxygen + Mermaid) is generated via:
   ```bash
   cmake --build --preset clang-debug --target docs
   ```
   Artifacts will appear under `build/clang-debug/docs`.

4. **Dependencies & overlays**  
   `vcpkg.json` lists the required packages. Overlay ports under `vcpkg-overlays/` provide policy helpers (`qlibs`), stdx utilities, Intel CIB scaffolding, and a boost-ext outcome shim to guarantee deterministic builds.

5. **Policies & sources**  
   Policy headers live under `include/slotmap/`. When changing or adding policies, keep the accompanying documentation in `docs/Architecture/` and `docs/Policies/` synchronized and update diagrams in `docs/Diagrams/`.

### Remote Devcontainer Workflow

See `docs/remote-devcontainer.md` for the end-to-end diagram and detailed instructions. In short:
- Run `./scripts/deploy_remote_devcontainer.sh` from your laptop. It pushes the current branch, copies your `.pub` key to the remote cache, and triggers `run_local_devcontainer.sh` on the host.
- The remote script rebuilds the sandbox (`~/dev/devcontainers/cpp-devcontainer`), stages your keys under `.devcontainer/ssh/`, and runs `devcontainer up --remove-existing-container`.
- Container port `2222` is published as host `9222`, so you can connect directly with `ssh -i ~/.ssh/id_ed25519 -p 9222 <remote-username>@c24s1.ch2` (the devcontainer user equals the remote host account) once the deploy finishes.

Troubleshooting tips, cleanup commands, and logging locations are captured in the doc so multiple developers can share the same remote workflow safely.

### Devcontainer Tooling Inventory

For a full list of packages and tools bundled by `.devcontainer/Dockerfile` (clang/LLVM, GCC, mold, MRDocs, vcpkg, ccache/sccache, ripgrep, etc.), see `docs/devcontainer-tools.md`. It mirrors the structure of the official devcontainers C++ image docs so you can quickly audit versions when planning upgrades.

### Devcontainer Build Automation Inspiration

We are aligning our container build steps with the [Beman Project infra-containers](https://github.com/bemanproject/infra-containers) model. Their `Dockerfile.devcontainer` and GitHub Actions workflow (`.github/workflows/devcontainer_ci.yml`) demonstrate how to matrix-build clang/gcc variants, push them to GHCR, and keep toolchains current via PPAs and Kitware mirrors. Future automation for SlotMap will follow a similar pattern (publish the devcontainer image after every main-branch update) so remote hosts can simply `docker pull` the latest image.

### Self-hosted Devcontainer Builds

Devcontainer images are now built on the self-hosted runner via `.github/workflows/build-devcontainer.yml`, which runs the full permutation matrix (gcc14/gcc15 × clang21/clang22/clangp2996) through `scripts/ci/build_devcontainers_ci.sh`. Pushes to `main` publish GHCR tags (permutation + SHA, optional `latest-<perm>`); pull requests build/validate without pushing. Tag maps are uploaded as workflow artifacts; see `.github/workflows/README.md` for details.

Rollbacks/retention are automated via `scripts/ci/ghcr_devcontainer_rollback.sh` and `scripts/ci/ghcr_devcontainer_prune.sh` (dry-run by default). Scanner images are pinned by digest and manifests are validated against loaded image IDs before any push. Runner/secret hygiene guidance lives in `docs/runner_security.md`.
