# Devcontainer SSH over Docker Context (for all AI agents)

This note explains how to make SSH into the devcontainer work when the container runs on a remote Docker engine via SSH context. All agents (Codex, Gemini, Cursor, Copilot, Grok, etc.) must follow this when configuring/building/running the devcontainer.

**Hard requirement when working from this MacBook:** all Docker image/devcontainer builds must run on the remote host via SSH Docker context. Do not run `docker build/buildx/bake` against the local engine. Use the helper `.devcontainer/scripts/build_remote_images.sh` (or set `DOCKER_CONTEXT` to the remote context) so images and caches live on the remote host.

> Note: Host/user/port values mentioned here (e.g., c24s1.ch2, 9222, rmanaloto) are examples. Replace with your own `DEVCONTAINER_REMOTE_HOST/USER/SSH_PORT` when executing commands.

## Goals
- Container runs on a remote host (e.g., `c24s1.ch2`) via Docker SSH context.
- Container user = remote host user (`rmanaloto` by default), so file ownership matches the host filesystem.
- SSH access into the container on published port 9222 using the developer’s keys without touching the host’s primary `~/.ssh`.
- Multiple permutations/ports: create a per-permutation env file (e.g., `config/env/devcontainer.gcc14-clang21.env`) with a unique `DEVCONTAINER_SSH_PORT`. Re-run `scripts/generate_cpp_devcontainer_ssh_config.sh --env-file <env> --output ~/.ssh/cpp-devcontainer-<name>.conf` to get a matching SSH alias. Point `CONFIG_ENV_FILE` to the same env when running `deploy_remote_devcontainer.sh` or `run_local_devcontainer.sh` so the devcontainer binds the right port.

## Required steps
1) **Docker context**  
   - Ensure a Docker SSH context exists for the host: `docker context create c24s1 --docker "host=ssh://<remote-user>@c24s1.ch2"` (per-host contexts).
   - Use/export `DOCKER_CONTEXT=<context>` when invoking the scripts.

2) **Workspace and SSH mount paths (remote host)**  
   - Workspace source on host: `/home/<remote-user>/dev/devcontainers/workspace` (configurable via `--remote-workspace`).  
   - SSH key cache on host: defaults to `/home/<remote-user>/.ssh` (public keys only). Override with `--remote-key-cache` if you store deploy keys elsewhere.

3) **User/uid/gid**  
   - Scripts default the container user/uid/gid to the remote host user (`CONTAINER_USER/UID/GID` resolved via `id -u/-g` over SSH). Override only if you know you need to.

4) **Key handling (public keys only)**  
   - `scripts/deploy_remote_devcontainer.sh` copies a single public key (default `~/.ssh/id_ed25519.pub`) into the remote key cache; it does **not** copy private keys. The legacy full `~/.ssh` sync is guarded by `SYNC_MAC_SSH=1` and is off by default—avoid enabling it unless you explicitly accept the risk.
   - `scripts/run_local_devcontainer.sh` stages `KEY_CACHE/*.pub` into `${workspace}/.devcontainer/ssh`, and `post_create.sh` installs them into `/home/<user>/.ssh/authorized_keys` inside the container.

5) **SSH agent mount**  
   - The devcontainer binds the remote host’s `SSH_AUTH_SOCK` into `/tmp/ssh-agent.socket` (see `devcontainer.json`). If no agent socket exists, `run_local_devcontainer.sh` starts one and attempts to add the host key. Outbound GitHub SSH from the container uses this socket; private keys never enter the container filesystem.

6) **Ports**  
   - devcontainer publishes container port 2222 as host port 9222 bound to `127.0.0.1` (see `.devcontainer/devcontainer.json` feature `sshd`).
   - Inbound SSH from your machine: use a tunnel or ProxyJump through the host, e.g. `ssh -J <remote-user>@c24s1.ch2 -p 9222 <container-user>@127.0.0.1` or pre-open `ssh -N -L 9222:127.0.0.1:9222 <remote-user>@c24s1.ch2`.
   - Scripts’ self-test now defaults to ProxyJump; disable with `--no-proxyjump` if you deliberately expose the port.

7) **Host key changes**  
   - Because the container is rebuilt, its SSH host key changes. If you see “REMOTE HOST IDENTIFICATION HAS CHANGED” on your Mac, remove the old entry: `ssh-keygen -R [c24s1.ch2]:9222`.

8) **Client config gotcha (UseKeychain)**  
   - The mounted `~/.ssh/config` from macOS may include `UseKeychain` directives, which OpenSSH inside Linux does not understand. If outbound SSH **from inside the container** is needed, guard macOS-only options (e.g., wrap in `Match exec "uname | grep -q Darwin"`) or provide a Linux-safe config.

## Files to consult
- `docs/remote-docker-context.md` — overall remote Docker workflow.
- `.devcontainer/devcontainer.json` — image, mounts, sshd feature, workspace paths.
- `scripts/deploy_remote_devcontainer.sh` — runs from your Mac; syncs keys, triggers remote build, resolves remote uid/gid.
- `scripts/run_local_devcontainer.sh` — runs on the remote host; bakes images and runs `devcontainer up`.
- `scripts/generate_cpp_devcontainer_ssh_config.sh` — writes a dedicated SSH config at `~/.ssh/cpp-devcontainer.conf` using `config/env/devcontainer.env` (keeps ProxyJump/tunnel settings out of your main ssh config).
- `.devcontainer/scripts/post_create.sh` — installs authorized_keys from `${workspace}/.devcontainer/ssh` and runs CMake preset.

## SSH config helper (one source of truth)
- Script: `scripts/generate_cpp_devcontainer_ssh_config.sh`
- Reads: `config/env/devcontainer.env` by default (or another file via `--env-file <path>`)
- Writes: `~/.ssh/cpp-devcontainer.conf` with:
  - `ProxyJump <user>@<host>` (host resolved via `ssh -G` so search domains/FQDN are applied)
  - `HostName 127.0.0.1`, `Port ${DEVCONTAINER_SSH_PORT}`, `User ${DEVCONTAINER_REMOTE_USER}`, `Include ~/.ssh/config`
- Usage examples:
  - Default env file: `./scripts/generate_cpp_devcontainer_ssh_config.sh`
  - Explicit env file (multiple devcontainers): `./scripts/generate_cpp_devcontainer_ssh_config.sh --env-file config/env/devcontainer-alt.env --output ~/.ssh/cpp-devcontainer-alt.conf`
  - Override proxy user (rare): `./scripts/generate_cpp_devcontainer_ssh_config.sh --proxy-user otheruser`
- Re-run the script whenever `DEVCONTAINER_REMOTE_HOST`, `DEVCONTAINER_REMOTE_USER`, or `DEVCONTAINER_SSH_PORT` changes in the env file.
- Connect with the generated config: `ssh -F ~/.ssh/cpp-devcontainer.conf cpp-devcontainer` (or point to the alternate output file you chose).

## Notes for CI / self-hosted runners
- Make cache path configurable: set `DEVCONTAINER_CACHE_DIR` (e.g., `${{ runner.temp }}/buildx-cache` in GitHub Actions) and `DEVCONTAINER_BUILDER_NAME` to isolate builders per runner.
- Registry cache optional: set `DEVCONTAINER_REGISTRY_REF` (e.g., `ghcr.io/<org>/cpp-devcontainer`) to enable cache-from/cache-to across runs, or `--no-registry-cache` to keep it local.
- Context and base tag: set `DOCKER_CONTEXT` to the remote engine context and `BASE_IMAGE`/`DEVCONTAINER_BASE_IMAGE` if you publish base images to a registry for CI reuse; otherwise keep using the remote engine’s local tags.
- Example runner env (self-hosted):  
  ```
  DOCKER_CONTEXT=ssh-<host>
  DEVCONTAINER_CACHE_DIR=/home/<runner>/buildx-cache
  DEVCONTAINER_BUILDER_NAME=devcontainer-ci
  DEVCONTAINER_REGISTRY_REF=ghcr.io/<org>/cpp-devcontainer  # or unset
  ```

## Quick verification
1) From your Mac (ProxyJump): `ssh -J rmanaloto@c24s1.ch2 -i ~/.ssh/id_ed25519 -p 9222 rmanaloto@127.0.0.1` (remove stale host key if prompted).
2) On the remote host: `ssh -i ~/.ssh/id_ed25519 -p 9222 <user>@127.0.0.1` (or whichever key matches your `KEY_CACHE`).
3) Inside the container (if needed): ensure `~/.ssh/authorized_keys` contains your pubkey and that `sshd` is running (`ps -ef | grep sshd`).
