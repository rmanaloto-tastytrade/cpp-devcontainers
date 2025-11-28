# AI Guide: Devcontainer Build, Bake, and SSH Workflow

Audience: AI agents (Claude/Code, Codex CLI) needing to manage SlotMap devcontainers on remote Docker hosts.

## Quick Facts
- Primary env defaults: `config/env/devcontainer.env` (host `c24s1.ch2`, user `rmanaloto`, port `9222`). Variant env for an extra container port: `config/env/devcontainer.gcc14-clang21.env` (port `9223`, same host/user).
- Authoritative workflow doc: `docs/remote-docker-context.md`.
- Images and tags are defined in `.devcontainer/docker-bake.hcl`; builds happen on the remote host via Docker SSH context.
- Default compiler inside the devcontainer: `clang-21` with `gcc-15` staged under `/opt/gcc-15` when the gcc15 permutation builds successfully.

## Image Topology (docker-bake.hcl)
- `base` (tag `dev-base:local`): Ubuntu 24.04, core build deps, gcc from PPA (14/15), clang via `llvm.sh` (numeric variants), binutils/gdb, ninja, make, git, cmake, perf, etc.
- Parallel tool stages (all inherit `prebuilt_base`): `gcc15` (source build under `/opt/gcc-15`), `clang_p2996` (Bloomberg fork under `/opt/clang-p2996`), `node_mermaid`, `mold`, `gh_cli`, `ccache`, `sccache`, `ripgrep`, `cppcheck`, `valgrind`, `python_tools`, `pixi`, `iwyu`, `mrdocs`, `jq`, `awscli`.
- `tools_merge`: copies staged tool artifacts into a single layer and bootstraps vcpkg.
- Final images:
  - `devcontainer` (tag `devcontainer:local`) uses defaults (`GCC_VERSION=15`, `CLANG_VARIANT=21`, IWYU on, clang_p2996 off).
  - Matrix tags (examples): `devcontainer:gcc14-clang21`, `devcontainer:gcc14-clang22`, `devcontainer:gcc14-clangp2996`, `devcontainer:gcc15-clang21`, `devcontainer:gcc15-clang22`, `devcontainer:gcc15-clangp2996`. Flags: `ENABLE_GCC15`, `ENABLE_CLANG_P2996`, `ENABLE_IWYU` adjust contents.
- Build args resolved dynamically:
  - `CLANG_QUAL` / `CLANG_DEV` scraped via `.devcontainer/scripts/resolve_llvm_branches.sh`.
  - `build_remote_images.sh` maps selector `qualification|development|p2996|numeric` → bake target and sets cache sources.

## Building Images (remote Docker context)
Recommended: run from the Mac, targeting the remote host via Docker SSH context.

1) Ensure env is loaded: `CONFIG_ENV_FILE=config/env/devcontainer.env`.
2) Build helper (remote):  
   ```bash
   .devcontainer/scripts/build_remote_images.sh \
     --llvm-version p2996   # or qualification|development|21|22
     --gcc-version 15       # 14 or 15
     # --all to build full matrix
   ```
   - Derives/creates context `ssh-${DEVCONTAINER_REMOTE_HOST}` unless overridden by `DEVCONTAINER_DOCKER_CONTEXT`.
   - Picks builder `devcontainer-remote` (or `DEVCONTAINER_BUILDER_NAME`); uses local/registry cache if configured.
   - Targets map to bake entries: `devcontainer_gcc${N}_clang_qual`, `_clang_dev`, `_clangp2996`, or `matrix` when `--all`.
3) If base is missing on the remote, bake it explicitly (one-time):  
   `DOCKER_CONTEXT=ssh-<host> docker buildx bake -f .devcontainer/docker-bake.hcl base --set base.output=type=docker`

## Running the Devcontainer
### From the Mac (preferred)
- Script: `scripts/deploy_remote_devcontainer.sh` (reads `config/env/devcontainer.env` unless overridden).
- Actions:
  - Pushes current branch.
  - Copies local public key to remote key cache (`~/devcontainers/ssh_keys`).
  - Invokes `scripts/run_local_devcontainer.sh` on the remote host (builds image if needed, runs `devcontainer up`).
  - Binds remote host port `DEVCONTAINER_SSH_PORT` → container port 2222 (`devcontainer.json` sets `127.0.0.1:<port>:2222`).
- Connect after deploy (example for default env):  
  `ssh -J rmanaloto@c24s1.ch2 -p 9222 slotmap@127.0.0.1` (replace user/port with env values). Keys are staged from the remote cache; SSH agent is mounted via `SSH_AUTH_SOCK`.

### When already on the remote host
- Script: `scripts/run_local_devcontainer.sh` (runs bake + `devcontainer up` locally on the host). Supply `DEVCONTAINER_SSH_PORT`, `CONTAINER_USER/UID/GID` if you need overrides.
- Workspace mount defaults: host path `~/dev/devcontainers/workspace` → container `/home/${DEVCONTAINER_USER}/workspace` (`devcontainer.json`).

## SSH Setup and Keys
- Host → remote Docker engine: Docker SSH context (`docker context create <name> --docker "host=ssh://<user>@<host>"`).
- Container inbound SSH:
  - Port: `DEVCONTAINER_SSH_PORT` (defaults 9222; `config/env/devcontainer.gcc14-clang21.env` example uses 9223).
  - Keys: public keys staged under `~/devcontainers/ssh_keys` on the remote; container `authorized_keys` populated in `post_create.sh`.
  - Agent forwarding: container binds `/tmp/ssh-agent.socket` from host `SSH_AUTH_SOCK`.
- ProxyJump examples:
  - From Mac into container: `ssh -J ${DEVCONTAINER_REMOTE_USER}@${DEVCONTAINER_REMOTE_HOST} -p ${DEVCONTAINER_SSH_PORT} ${DEVCONTAINER_USER}@127.0.0.1`.
  - Git over 443 inside container verified via `ssh -T git@ssh.github.com -p 443`.

## Parsing Config for Hosts/Ports/Users
- Primary file: `config/env/devcontainer.env` (sets `DEVCONTAINER_REMOTE_HOST`, `DEVCONTAINER_REMOTE_USER`, `DEVCONTAINER_SSH_PORT`, optional `DEVCONTAINER_DOCKER_CONTEXT`, `DEVCONTAINER_BUILDER_NAME`).
- Alternate env examples live alongside (e.g., `config/env/devcontainer.gcc14-clang21.env` for a secondary SSH port).
- Scripts read `CONFIG_ENV_FILE` override if provided, then allow CLI flags (`--remote-host`, `--remote-user`, `--remote-port`, `--docker-context`, etc.).
- Container identity defaults to remote user unless `CONTAINER_USER/UID/GID` are passed; resolved via `ssh id -u/-g` within `deploy_remote_devcontainer.sh`.

## Current State and Pending Items
- Latest change: `.devcontainer/Dockerfile` now uses GCC prerequisite mirrors `gcc.gnu.org` / `ftpmirror.gnu.org` and clears the gcc15 build dir before configuring.
- GCC 15 source build still fails intermittently in the `devcontainer_gcc15_clangp2996` target due to `config.cache` pollution during configure; last bake was interrupted mid-run. Next step: rerun bake; if the error persists, add an explicit `config.cache` purge/distclean inside the gcc15 stage.
- Remote images present on `ssh-c24s1.ch2`: `dev-base:local`, `devcontainer:local`, `devcontainer:gcc14-clang21`, `devcontainer:gcc15-clang21` (others pending successful bake).

## Cheat Sheet (commands)
- Build default (qualification clang + gcc15):  
  `.devcontainer/scripts/build_remote_images.sh`
- Build clang-p2996 + gcc15:  
  `.devcontainer/scripts/build_remote_images.sh --llvm-version p2996`
- Build full matrix:  
  `.devcontainer/scripts/build_remote_images.sh --all`
- Deploy/run devcontainer on remote host (from Mac):  
  `DEVCONTAINER_REMOTE_HOST=c24s1.ch2 DEVCONTAINER_REMOTE_USER=rmanaloto DEVCONTAINER_SSH_PORT=9222 ./scripts/deploy_remote_devcontainer.sh`
- List remote images:  
  `docker --context ssh-c24s1.ch2 images`
