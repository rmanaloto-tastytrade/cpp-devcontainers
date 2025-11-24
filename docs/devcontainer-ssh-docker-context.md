# Devcontainer SSH over Docker Context (for all AI agents)

This note explains how to make SSH into the devcontainer work when the container runs on a remote Docker engine via SSH context. All agents (Codex, Gemini, Cursor, Copilot, Grok, etc.) must follow this when configuring/building/running the devcontainer.

> Note: Host/user/port values mentioned here (e.g., c24s1.ch2, 9222, rmanaloto) are examples. Replace with your own `DEVCONTAINER_REMOTE_HOST/USER/SSH_PORT` when executing commands.

## Goals
- Container runs on a remote host (e.g., `c24s1.ch2`) via Docker SSH context.
- Container user = remote host user (`rmanaloto` by default), so file ownership matches the host filesystem.
- SSH access into the container on published port 9222 using the developer’s keys without touching the host’s primary `~/.ssh`.

## Required steps
1) **Docker context**  
   - Ensure a Docker SSH context exists for the host: `docker context create c24s1 --docker "host=ssh://<remote-user>@c24s1.ch2"` (per-host contexts).
   - Use/export `DOCKER_CONTEXT=<context>` when invoking the scripts.

2) **Workspace and SSH mount paths (remote host)**  
   - Workspace source on host: `/home/<remote-user>/dev/devcontainers/workspace` (configurable via `--remote-workspace`).  
   - SSH key sync dir on host: `/home/<remote-user>/devcontainers/ssh_keys`.

3) **User/uid/gid**  
   - Scripts default the container user/uid/gid to the remote host user (`CONTAINER_USER/UID/GID` resolved via `id -u/-g` over SSH). Override only if you know you need to.

4) **Key sync**  
   - `scripts/deploy_remote_devcontainer.sh` rsyncs your local `~/.ssh/` to the remote `ssh_keys` dir (uses `rsync --rsync-path="mkdir -p <dir> && rsync"`; toggle via `SYNC_MAC_SSH=0/1`).
   - Staged public keys are copied into `${workspace}/.devcontainer/ssh` and then into `/home/<user>/.ssh/authorized_keys` inside the container during `post_create.sh`.

5) **Ports**  
   - devcontainer publishes container port 2222 as host port 9222 (see `.devcontainer/devcontainer.json` feature `sshd`).
   - Inbound SSH from your machine: `ssh -i ~/.ssh/id_ed25519 -p 9222 <container-user>@c24s1.ch2`.
   - Scripts’ self-test now targets port 9222.

6) **Host key changes**  
   - Because the container is rebuilt, its SSH host key changes. If you see “REMOTE HOST IDENTIFICATION HAS CHANGED” on your Mac, remove the old entry: `ssh-keygen -R [c24s1.ch2]:9222`.

7) **Client config gotcha (UseKeychain)**  
   - The mounted `~/.ssh/config` from macOS may include `UseKeychain` directives, which OpenSSH inside Linux does not understand. If outbound SSH **from inside the container** is needed, guard macOS-only options (e.g., wrap in `Match exec "uname | grep -q Darwin"`) or provide a Linux-safe config.

8) **Agent vs. key file**  
   - The current flow copies key files; agent forwarding through Docker SSH contexts is not set up. To enable agent forwarding, you’d need to expose a reachable agent socket and adjust `ssh_config` accordingly—out of scope for the base workflow.

## Files to consult
- `docs/remote-docker-context.md` — overall remote Docker workflow.
- `.devcontainer/devcontainer.json` — image, mounts, sshd feature, workspace paths.
- `scripts/deploy_remote_devcontainer.sh` — runs from your Mac; syncs keys, triggers remote build, resolves remote uid/gid.
- `scripts/run_local_devcontainer.sh` — runs on the remote host; bakes images and runs `devcontainer up`.
- `.devcontainer/scripts/post_create.sh` — installs authorized_keys from `${workspace}/.devcontainer/ssh` and runs CMake preset.

## Quick verification
1) From your Mac: `ssh -i ~/.ssh/id_ed25519 -p 9222 rmanaloto@c24s1.ch2` (remove stale host key if prompted).
2) On the remote host: `ssh -i /home/<user>/devcontainers/ssh_keys/id_ed25519 -p 9222 <user>@localhost`.
3) Inside the container (if needed): ensure `~/.ssh/authorized_keys` contains your pubkey and that `sshd` is running (`ps -ef | grep sshd`).
