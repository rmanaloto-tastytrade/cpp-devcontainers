## Purpose
Fast on-boarding for AI agents (Claude/Code, Codex CLI) to build, run, and validate SlotMap devcontainers on the remote Docker host.

## What we build
- Matrix images come from `.devcontainer/docker-bake.hcl` and follow the tags `cpp-devcontainer:gcc{14|15}-clang{21|22|p2996}` plus `cpp-devcontainer:local` (default clang-p2996/gcc15).
- Toolchain layout: everything manually installed lives under `/usr/local` inside the final image (gcc builds symlinked there, clang installs from apt.llvm.org pockets, p2996 staged under `/usr/local/clang-p2996`).
- Branch→version mapping is centralized in `scripts/clang_branch_utils.sh`:
  - `stable→20`, `qualification→21`, `development→22`, numeric passthrough.
  - APT pockets: 22 uses `llvm-toolchain-noble`, others use `llvm-toolchain-noble-<version>`.
- Dockerfile args surfaced to bake: `CLANG_VARIANT`, `CLANG_BRANCH`, `LLVM_APT_POCKET`, `GCC_VERSION`, `ENABLE_CLANG_P2996`, `ENABLE_GCC15`, `ENABLE_IWYU`.

## Build workflow (Docker Bake)
- Bake file: `.devcontainer/docker-bake.hcl`.
- Helper scripts:
  - `.devcontainer/scripts/resolve_llvm_branches.sh` (discovers latest qualification/development numbers).
  - `scripts/clang_branch_utils.sh` (maps branch name → variant/pocket for Dockerfile and verify).
  - `.devcontainer/scripts/build_remote_images.sh` (not modified today, still drives the matrix).
- Bake args are **not** inferred from the env files by `run_local_devcontainer.sh`; it uses the defaults in `docker-bake.hcl` (CLANG_VARIANT=21, ENABLE_CLANG_P2996=0, GCC_VERSION=15) unless you pass `--set` overrides. Also, if `DEVCONTAINER_SKIP_BAKE=1` is set in an env file, the script will reuse the existing tag instead of rebuilding. Bake the permutation you need (via `docker buildx bake --set '*.args.CLANG_VARIANT'=... --set '*.args.ENABLE_CLANG_P2996'=...`) before launching.
- To build a permutation on the remote host from the Mac:  
  ```bash
  DOCKER_HOST=ssh://rmanaloto@c24s1.ch2 \
  CONFIG_ENV_FILE=config/env/devcontainer.gcc15-clang22.env \
  docker buildx bake -f .devcontainer/docker-bake.hcl devcontainer_gcc15_clang22
  ```
- Full matrix is available: `cpp-devcontainer:gcc14-clang21`, `gcc14-clang22`, `gcc14-clangp2996`, `gcc15-clang21`, `gcc15-clang22`, `gcc15-clangp2996`, plus `cpp-devcontainer:local`.

## Running the devcontainers
- Run on the remote host (preferred): `scripts/run_local_devcontainer.sh` (invoked via SSH by `scripts/deploy_remote_devcontainer.sh`). It rsyncs the repo into a sandbox, optionally bakes, then runs `devcontainer up` with `127.0.0.1:<port>→2222`.
- From the Mac, connect with ProxyJump:  
  `ssh -J ${DEVCONTAINER_REMOTE_USER}@${DEVCONTAINER_REMOTE_HOST} -p ${DEVCONTAINER_SSH_PORT} ${CONTAINER_USER}@127.0.0.1`
- Shortcut script (clears known_hosts entry, then SSH):  
  `CONFIG_ENV_FILE=config/env/devcontainer.gcc15-clang22.env scripts/ssh_devcontainer.sh`
- Per-permutation env files (ports auto-increment):  
  - `config/env/devcontainer.env` (gcc15-clangp2996, port 9222)  
  - `config/env/devcontainer.gcc14-clang21.env` (9223)  
  - `config/env/devcontainer.gcc14-clang22.env` (9227)  
  - `config/env/devcontainer.gcc14-clangp2996.env` (9228)  
  - `config/env/devcontainer.gcc15-clang21.env` (9225)  
  - `config/env/devcontainer.gcc15-clang22.env` (9226)  
  - `config/env/devcontainer.gcc15-clangp2996.env` (9224)

## Validation pipeline (fully scripted)
- Use `scripts/verify_devcontainer.sh` to check both the image and a running container. It:
  - Sources `CONFIG_ENV_FILE` (defaults to `config/env/devcontainer.env`) and `scripts/clang_branch_utils.sh`.
  - Infers expected compiler versions from the env/tag, builds a tiny tool check script, and runs it with `docker run` against the image.
  - Cleans `known_hosts` entry for the target SSH port, then SSHes (ProxyJump through `${DEVCONTAINER_REMOTE_HOST}`) into the running container and re-runs the same checks. `--require-ssh` enforces container reachability.
- Example (Mac → remote docker via SSH transport):  
  ```bash
  DOCKER_HOST=ssh://rmanaloto@c24s1.ch2 \
  CONFIG_ENV_FILE=config/env/devcontainer.gcc14-clang22.env \
  scripts/verify_devcontainer.sh --require-ssh
  ```
- Current results (all succeeded via `--require-ssh`): ports 9222/9223/9224/9225/9226/9227/9228 with expected clang/gcc/ninja/cmake/vcpkg/mrdocs.

## SSH and key handling
- Host→engine: set `DOCKER_HOST=ssh://<user>@<host>` or create a docker context (see `docs/remote-docker-context.md`).
- Container inbound:
  - Port from the env files; ProxyJump uses `${DEVCONTAINER_REMOTE_USER}@${DEVCONTAINER_REMOTE_HOST}`.
  - Keys staged from the remote `~/devcontainers/ssh_keys` directory; `run_local_devcontainer.sh` copies all `*.pub` from that cache into `.devcontainer/ssh`.
  - Agent forwarding: container binds `/tmp/ssh-agent.socket` from host `SSH_AUTH_SOCK`.
  - Host key hygiene: `verify_devcontainer.sh` runs `ssh-keygen -R "[127.0.0.1]:<port>"` before connecting.

## Image contents (permutation highlights)
- clang21/22 come from apt.llvm.org pockets chosen by `LLVM_APT_POCKET`; clang22 uses the unversioned `llvm-toolchain-noble`.
- gcc14/15 built from source and installed under `/usr/local` with versioned symlinks.
- Optional extras toggled by bake flags: p2996 toolchain, IWYU, Node+mermaid, mold, ccache/sccache, Python+pipx toolset, vcpkg bootstrap, gh-cli, ripgrep/cppcheck/valgrind, mrdocs, jq, awscli, pixi.

## Operational checklist
- For a fresh agent session:
  1) Pick the env file for the permutation you want.
  2) Build (or skip if already built) with `docker buildx bake ...` using `DOCKER_HOST=ssh://...`.
  3) Run the devcontainer via `deploy_remote_devcontainer.sh` (Mac) or `run_local_devcontainer.sh` (on the host).
  4) Validate with `scripts/verify_devcontainer.sh --require-ssh` using the same env.
  5) If SSH fails, clear hostkeys with `ssh-keygen -R "[127.0.0.1]:<port>"` (already done in the script) and retry.

## Current state (validated)
- All permutations are built on `c24s1.ch2` and running:  
  `cpp-devcontainer:local` (9222), `gcc14-clang21` (9223), `gcc14-clang22` (9227), `gcc14-clangp2996` (9228), `gcc15-clang21` (9225), `gcc15-clang22` (9226), `gcc15-clangp2996` (9224).
- Verification shows expected compiler/tool versions in both image and running containers; clang22 now installs from the development pocket without 404s.

## Pointers to other docs
- Remote docker context details: `docs/remote-docker-context.md`
- SSH specifics: `docs/ssh-configurations.md`, `docs/ssh-key-management-options.md`, `docs/devcontainer-ssh-docker-context.md`
- Branch comparison notes: `docs/devcontainer-branch-comparison.md`
