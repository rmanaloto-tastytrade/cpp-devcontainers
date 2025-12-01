# Remote Docker Context Devcontainer Workflow

This document defines the **authoritative** way to build and run the SlotMap devcontainer using a remote Docker engine. All AI agent interactions must follow this document for configuration, build, and run.

> Note: Host/user/port values mentioned here (e.g., c24s1, 9222) are examples. Replace with your own `DEVCONTAINER_REMOTE_HOST/DEVCONTAINER_REMOTE_USER/DEVCONTAINER_SSH_PORT` when following commands.

## Goals
- Build and run the devcontainer on remote x86_64 hosts (example: c24s1) via Docker SSH contexts.
- Keep the devcontainer user aligned with the developer’s identity (uid/gid) for correct file ownership.
- Make SSH/Git work inside the container without touching the remote host’s primary `~/.ssh`.
- Avoid manual SSH sessions; use contexts and scripts to drive remote builds/runs.

## Prerequisites
- Remote host with Docker available over SSH (no rootless quirks assumed).
- Your SSH access to the remote host.
- Remote host user/uid/gid will be used for the container by default (configurable via env/args if needed).
- SSH keys available on the remote host (public keys only for authorized_keys); private keys remain on the host agent.

## Setup: Docker SSH Context
Create a context per host (examples only: c24s1, c090s4.ny5, c0802s4.ny5):
```bash
docker context create <context-name> --docker "host=ssh://<remote-user>@<remote-host>"
```
Use the context when running scripts or set `DOCKER_CONTEXT=<context-name>`. The deploy script accepts `--docker-context` and will create the context if missing.

## User/UID/GID
The container user is supplied via the scripts. By default, `deploy_remote_devcontainer.sh` aligns to the **remote host user** (uid/gid resolved over SSH); override via `CONTAINER_USER`, `CONTAINER_UID`, `CONTAINER_GID` if needed. When running `run_local_devcontainer.sh` directly on a host, defaults follow the current host user. Keep container uid/gid aligned with your Git identity so file ownership stays consistent across hosts.

## SSH Keys for Git
- Private keys stay on the remote host; only public keys are staged for container `authorized_keys`.
- The container binds the host SSH agent socket (`SSH_AUTH_SOCK`), so outbound Git/SSH uses the host agent (no private keys in the container).
- Avoid syncing `~/.ssh` from the laptop; if you must add a key, use `ssh-copy-id` or a public-key sync tool. Do not overwrite the remote `~/.ssh`.

## Workflow (use this)
1) Ensure remote context exists: `docker context use <context-name>` (or set `DOCKER_CONTEXT=<context-name>`).
2) Run local validations: `./scripts/pre_commit.sh` (fix issues).
3) Commit and push.
4) Deploy/rebuild on the remote using the context:
   ```bash
   DEVCONTAINER_REMOTE_HOST=<host> DEVCONTAINER_REMOTE_USER=<user> DEVCONTAINER_SSH_PORT=<port> ./scripts/deploy_remote_devcontainer.sh
   ```
   This:
   - Pushes current branch.
   - Uses the remote Docker engine (via context) to validate/bake/build images and run `devcontainer up` with host/user/port from env/args.
5) Connect: port is bound to `127.0.0.1:<port>` on the host. Use a tunnel or ProxyJump, e.g. `ssh -J <remote-user>@<host> -i ~/.ssh/id_ed25519 -p <port> <container-user>@127.0.0.1`.

## Notes & Options
- Workspace location: recommended to use a remote checkout to avoid slow SSHFS. Default `workspaceFolder` is `/home/${USER}/workspace` (generic). `workspaceMount` binds the repo into that path; `deploy_remote_devcontainer.sh` defaults the host path to `~/dev/devcontainers/workspace` (override with `--remote-workspace`).
- Volumes: caches are consolidated under a single volume (`cppdev-cache`) mounting `/cppdev-cache` in the container (vcpkg downloads + binary cache, ccache/sccache, and a persistent `/tmp`).
- Multiple hosts/containers: create distinct contexts per host and per-host workspaces to avoid collisions.
- User identity: set `user.name`/`user.email` inside the container to your desired Git identity.
- Inbound SSH to the container uses staged public keys from `~/devcontainers/ssh_keys`; outbound SSH/Git uses the mounted keys. Post-deploy, the remote script attempts an SSH login to port 2222 using `id_ed25519` from the synced key cache; if that fails, treat the deploy as suspect and investigate keys/port mapping.

## If you must keep workspace on Mac (not recommended)
- You can mount a local path over SSHFS/bind into the remote container, but expect higher latency and possible load on your Mac. Prefer remote-host checkout unless required.

## Files to consult
- `scripts/deploy_remote_devcontainer.sh` — drives sync + remote build/run via context.
- `scripts/run_local_devcontainer.sh` — remote-side rebuild and `devcontainer up`.
- `.devcontainer/devcontainer.json` — image, mounts (including `.ssh`), features.
- `.devcontainer/docker-bake.hcl` — bake targets/versions; use with the remote context.
- `docs/devcontainer-ssh-docker-context.md` — SSH-specific setup when using Docker SSH contexts.
