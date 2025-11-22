# Remote Docker Context Devcontainer Workflow

This document defines the **authoritative** way to build and run the SlotMap devcontainer using a remote Docker engine. All AI agent interactions must follow this document for configuration, build, and run.

## Goals
- Build and run the devcontainer on remote x86_64 hosts (e.g., c24s1) via Docker SSH contexts.
- Keep the devcontainer user aligned with the developer’s identity (uid/gid) for correct file ownership.
- Make SSH/Git work inside the container without touching the remote host’s primary `~/.ssh`.
- Avoid manual SSH sessions; use contexts and scripts to drive remote builds/runs.

## Prerequisites
- Remote host with Docker available over SSH (no rootless quirks assumed).
- Your SSH access to the remote host.
- macOS `uid/gid` values (run `id -u`, `id -g` locally) if you want the container user to match your Mac user.
- Your SSH keys available on the remote (prefer a dedicated path such as `~/devcontainers/ssh_keys` to avoid overwriting the remote `~/.ssh`).

## Setup: Docker SSH Context
Create a context per host (examples: c24s1, c0903s4.ny5, c0802s4.ny5):
```bash
docker context create c24s1 --docker "host=ssh://<remote-user>@c24s1.ch2"
docker context create c0903s4 --docker "host=ssh://<remote-user>@c0903s4.ny5"
docker context create c0802s4 --docker "host=ssh://<remote-user>@c0802s4.ny5"
```
Use the context when running scripts or set `DOCKER_CONTEXT=<context-name>`. The deploy script accepts `--docker-context` and will create the context if missing.

## User/UID/GID
The container user is supplied via the scripts. By default, `deploy_remote_devcontainer.sh` aligns to the **remote host user** (uid/gid resolved over SSH); override via `CONTAINER_USER`, `CONTAINER_UID`, `CONTAINER_GID` if needed. When running `run_local_devcontainer.sh` directly on a host, defaults follow the current host user. Keep container uid/gid aligned with your Git identity so file ownership stays consistent across hosts.

## SSH Keys for Git
- Do **not** overwrite the remote `~/.ssh`. Keep your Mac keys under a dedicated remote path, e.g., `~/devcontainers/ssh_keys`.
- `scripts/deploy_remote_devcontainer.sh` can sync your local `~/.ssh` to the remote sync dir (defaults to `~/devcontainers/ssh_keys`, toggle via `SYNC_MAC_SSH=0/1`, `SSH_SYNC_SOURCE`, `REMOTE_SSH_SYNC_DIR`). It uses `rsync` with `--rsync-path="mkdir -p <remote_dir> && rsync"` and `--chmod=F600,D700`; it accepts `RSYNC_SSH` (default `ssh -o StrictHostKeyChecking=accept-new`) to both create the directory and sync in one command. TODO: tighten later (sync only needed keys/config or switch to a remote agent).
- `.devcontainer/devcontainer.json` bind-mounts that sync dir into the container `~/.ssh`, so outbound Git/SSH works without touching the remote’s primary `~/.ssh`.
- If you prefer an agent, run an agent on the remote and mount its socket; forwarding your Mac agent directly to the remote Docker daemon is not supported by default contexts.

## Workflow (use this)
1) Ensure remote context exists: `docker context use c24s1` (or set `DOCKER_CONTEXT=c24s1`).
2) Run local validations: `./scripts/pre_commit.sh` (fix issues).
3) Commit and push.
4) Deploy/rebuild on the remote using the context:
   ```bash
   ./scripts/deploy_remote_devcontainer.sh --remote-host c24s1.ch2
   ```
   This:
   - Pushes current branch.
   - Syncs your local `.ssh` to `~/devcontainers/ssh_keys` on the remote (configurable).
   - Uses the remote Docker engine (via context) to validate/bake/build images and run `devcontainer up`.
5) Connect: `ssh -i ~/.ssh/id_ed25519 -p 9222 <container-user>@c24s1.ch2` (username = container user, port published by the devcontainer).

## Notes & Options
- Workspace location: recommended to use a remote checkout to avoid slow SSHFS. Default `workspaceFolder` is `/home/${USER}/workspace` (generic). `workspaceMount` binds the repo into that path; `deploy_remote_devcontainer.sh` defaults the host path to `~/dev/devcontainers/workspace` (override with `--remote-workspace`).
- Volumes: vcpkg downloads cached via a named volume on the remote (`slotmap-vcpkg`). You can add ccache/sccache volumes similarly.
- Multiple hosts/containers: create distinct contexts (`c24s1`, `c24s2`, …) and per-host workspaces to avoid collisions.
- User identity: set `user.name`/`user.email` inside the container to your desired Git identity.
- Inbound SSH to the container uses staged public keys from `~/devcontainers/ssh_keys`; outbound SSH/Git uses the mounted keys. Post-deploy, the remote script attempts an SSH login to port 2222 using `id_ed25519` from the synced key cache; if that fails, treat the deploy as suspect and investigate keys/port mapping.

## If you must keep workspace on Mac (not recommended)
- You can mount a local path over SSHFS/bind into the remote container, but expect higher latency and possible load on your Mac. Prefer remote-host checkout unless required.

## Files to consult
- `scripts/deploy_remote_devcontainer.sh` — drives sync + remote build/run via context.
- `scripts/run_local_devcontainer.sh` — remote-side rebuild and `devcontainer up`.
- `.devcontainer/devcontainer.json` — image, mounts (including `.ssh`), features.
- `.devcontainer/docker-bake.hcl` — bake targets/versions; use with the remote context.
