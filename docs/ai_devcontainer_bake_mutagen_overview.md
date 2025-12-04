# AI Agent Guide: Docker Bake, Devcontainer Matrix, and Mutagen Sync

This guide is for AI agents to reproduce and audit the devcontainer workflow: Docker buildx bake matrix, remote devcontainer bring-up, SSH/ProxyJump settings, and Mutagen macOS → remote devcontainer sync. Everything below is scriptable; avoid manual tweaks.

## Build Matrix (docker-bake)
- Bake file: `.devcontainer/docker-bake.hcl`.
- Base builder target: `base` → tag `${BASE_TAG}` (default `cpp-cpp-dev-base:local`), Ubuntu 24.04 with common toolchain deps.
- Devcontainer target: `devcontainer` → tag `${TAG}` (default `cpp-cpp-devcontainer:local`), depends on `tools_merge`.
- Tool stages (all cached/merged): clang-p2996, node+mermaid, mold, gh-cli, gcc15, ccache, sccache, ripgrep, cppcheck, valgrind, python_tools (uv/ruff/ty), pixi, iwyu, mrdocs, jq, awscli.
- Permutations (tags shown):
  - `devcontainer_gcc14_clang_qual` → `cpp-cpp-devcontainer:gcc14-clang21` (ENABLE_GCC15=0, ENABLE_CLANG_P2996=0).
  - `devcontainer_gcc14_clang_dev`  → `cpp-cpp-devcontainer:gcc14-clang22`.
  - `devcontainer_gcc14_clangp2996` → `cpp-cpp-devcontainer:gcc14-clangp2996` (ENABLE_CLANG_P2996=1, IWYU off).
  - `devcontainer_gcc15_clang_qual` → `cpp-cpp-devcontainer:gcc15-clang21`.
  - `devcontainer_gcc15_clang_dev`  → `cpp-cpp-devcontainer:gcc15-clang22`.
  - `devcontainer_gcc15_clangp2996` → `cpp-cpp-devcontainer:gcc15-clangp2996` (ENABLE_CLANG_P2996=1, IWYU off).
- Notable args/versions: clang variants 21/22/p2996; GCC 14/15; Mutagen v0.18.1; Ninja 1.13.1; cmake 4.2.0; mold 2.40.4; MRDocs 0.8.0; Node 25.2.1; ccache/sccache enabled. p2996 builds use JOBS = 75% of nproc by default (`CLANG_P2996_JOBS=0` → computed at build).
- Metadata: `run_local_devcontainer.sh` writes `--print` manifest and `--metadata-file` into `/home/<user>/dev/devcontainers/build_meta/devcontainer_<target>_<ts>_{print,metadata}.json` on the remote host.

## Remote Build/Bring-up Workflow (scripts)
- Primary scripts:
  - `scripts/run_local_devcontainer.sh` (run on remote host) – rsyncs repo into sandbox, stages SSH pubkeys, bake+build images, `devcontainer up`.
  - `scripts/deploy_remote_devcontainer.sh` (optional from Mac) – pushes branch and SSHes to run the above.
  - `scripts/verify_devcontainer.sh --require-ssh` – validates image/toolchain/SSH, and runs Mutagen when `REQUIRE_MUTAGEN=1`.
  - `scripts/cleanup_devcontainers.sh` – removes containers/images matching host suffix (`vsc-.*_${HOST_SUFFIX}_`).
- Key env/config files (remote host, per permutation):
  - `config/env/devcontainer.c090s4.gcc14-clang21.env` (and gcc14/clang22, gcc14/clangp2996, gcc15/clang21, gcc15/clang22, gcc15/clangp2996).
    - `SANDBOX_PATH=/home/rmanaloto/dev/devcontainers/cppdev_c090s4_<perm>`
    - `WORKSPACE_PATH=/home/rmanaloto/dev/devcontainers/workspace_c090s4_<perm>`
    - `DEVCONTAINER_SSH_PORT` 9501–9506 (mapped to container 2222)
    - `DEVCONTAINER_IMAGE=cpp-devcontainer:<perm>`; `CLANG_VARIANT`, `GCC_VERSION`, `REQUIRE_MUTAGEN=1`.
- Devcontainer runtime (from `devcontainer.json`/scripts):
  - Mounts: workspace bind, volume `cppdev-cache` for `/cppdev-cache` (vcpkg downloads/binary cache, ccache/sccache, tmp), SSH agent socket bind, publishes `127.0.0.1:<port>` → container `2222`.
  - Env inside container: `CC=clang-XX`, `CXX=clang++-XX`, `VCPKG_ROOT=/opt/vcpkg`, `VCPKG_DOWNLOADS=/cppdev-cache/vcpkg-downloads`, `VCPKG_DEFAULT_BINARY_CACHE=/cppdev-cache/vcpkg-archives`, `TMPDIR=/cppdev-cache/tmp`, `MRDOCS_EXECUTABLE=/opt/mrdocs/bin/mrdocs`, `SSH_AUTH_SOCK=/tmp/ssh-agent.socket`.
  - User: remote host user (uid/gid 1000) with passwordless sudo; authorized_keys populated from staged `~/.ssh/*.pub`.
  - Post-create runs vcpkg install and clears stale CMake build dirs.

## SSH / ProxyJump
- Devcontainer SSH is bound to `127.0.0.1:<DEVCONTAINER_SSH_PORT>` on the remote host; connect via ProxyJump through the host:
  - `ssh -J <remote_user>@<remote_host> -i <key> -p <port> <remote_user>@127.0.0.1`
- Scripts use `StrictHostKeyChecking=accept-new` and clear stale entries (`ssh-keygen -R "[127.0.0.1]:<port>"`) before connecting.

## Mutagen (macOS → remote devcontainer)
- Host setup: `CONFIG_ENV_FILE=config/env/devcontainer.c090s4.<perm>.env scripts/setup_mutagen_host.sh`
  - Writes `~/.mutagen/cpp-devcontainer_ssh_config` (ProxyJump + port + user + key) and `~/.mutagen.yml` defaults.
  - Installs ssh/scp wrappers under `~/.mutagen/bin` (logs to `/tmp/mutagen_ssh_invocations.log`) and restarts the Mutagen daemon with `MUTAGEN_SSH_COMMAND`/`MUTAGEN_SSH_PATH` pointing at the wrapper (fixes the “host becomes ssh” bug).
- Validation: `CONFIG_ENV_FILE=... REQUIRE_MUTAGEN=1 scripts/verify_devcontainer.sh --require-ssh` (or `scripts/verify_mutagen.sh` directly) creates a temporary two-way session syncing `<repo>/.mutagen_probe` ↔ `/home/<container_user>/workspace/.mutagen_probe`; requires Mutagen 0.18.1 on the Mac. Sessions must report `Status: Watching/Connected` with probes present on both ends.

## Step-by-Step (repeatable)
1) On macOS: ensure clean repo; optional `scripts/deploy_remote_devcontainer.sh` to push and trigger remote build.
2) On remote host (c0903s4.ny5): `CONFIG_ENV_FILE=config/env/devcontainer.c090s4.<perm>.env ./scripts/run_local_devcontainer.sh`
   - Writes bake manifest/metadata to `~/dev/devcontainers/build_meta/`.
   - Bakes base + dev image per env args; runs `devcontainer up` with proper user/ports/caches.
3) On macOS: `CONFIG_ENV_FILE=config/env/devcontainer.c090s4.<perm>.env scripts/setup_mutagen_host.sh`
4) Validate: `DOCKER_HOST=ssh://rmanaloto@c0903s4.ny5 CONFIG_ENV_FILE=... REQUIRE_MUTAGEN=1 scripts/verify_devcontainer.sh --require-ssh`
   - Includes tool checks (clang/gcc/ninja/cmake/vcpkg/mrdocs/mutagen) and Mutagen probe.
5) Develop: SSH/ProxyJump to the container port; Mutagen keeps the workspace in sync.

## Current Remote Ports/Permutations (c0903s4.ny5)
- 9501: gcc14-clang21 (`cppdev_c090s4_gcc14_clang21`)
- 9502: gcc14-clang22
- 9503: gcc14-clangp2996
- 9504: gcc15-clang21
- 9505: gcc15-clang22
- 9506: gcc15-clangp2996

## Files to Read for Full Context
- Scripts: `scripts/run_local_devcontainer.sh`, `scripts/deploy_remote_devcontainer.sh`, `scripts/verify_devcontainer.sh`, `scripts/verify_mutagen.sh`, `scripts/setup_mutagen_host.sh`, `scripts/cleanup_devcontainers.sh`.
- Config: `config/env/devcontainer.c090s4*.env`, `.devcontainer/docker-bake.hcl`, `.devcontainer/devcontainer.json`.
- Docs: `docs/remote-devcontainer.md`, `docs/CURRENT_WORKFLOW.md`, `docs/ai_devcontainer_workflow.md`, `docs/mutagen-validation.md` (mutagen status), this file.

## Future Split (repo extraction)
- The devcontainer/Docker build scripts and bake file can move to a dedicated infra repo. This project would consume prebuilt images (`cpp-cpp-devcontainer:<perm>`) and reuse `run_local_devcontainer.sh`/`verify_devcontainer.sh` with only config/env overrides.
