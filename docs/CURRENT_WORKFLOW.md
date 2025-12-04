# Current Workflow: Remote Devcontainer Architecture

**Last Updated:** 2025-02-12  
**Status:** Production (multi-permutation devcontainers running)

> Host/user/port values shown below (e.g., c24s1.ch2, 9222, rmanaloto) are examples. Set `DEVCONTAINER_REMOTE_HOST/USER/SSH_PORT` (or `config/env/devcontainer.env`) to your own values before running scripts.

## Update (2025-02-12)
- All permutations are active on the remote host: gcc14/15 × clang21/22/p2996 on ports 9222–9228 (see `config/env/devcontainer*.env` for exact bindings).
- Clang branch mapping is centralized (`scripts/clang_branch_utils.sh`), so branch names (stable/qualification/development) translate to apt pockets automatically during bake and verification.
- Container user defaults to the remote host user (`rmanaloto`), uid/gid resolved on the host during deploy.
- Only public keys are staged: `deploy_remote_devcontainer.sh` copies the chosen `*.pub` to the host cache (default `~/.ssh`); `run_local_devcontainer.sh` installs them into container `authorized_keys`.
- Host SSH agent socket is bind-mounted (`SSH_AUTH_SOCK` → `/tmp/ssh-agent.socket`), so outbound GitHub SSH from the container uses the host agent with port 443 fallback. No private keys live in the container filesystem.
- Port binding is limited to loopback: container SSH is published on `127.0.0.1:${DEVCONTAINER_SSH_PORT:-9222}`; connect via ProxyJump or an SSH tunnel through the host.

## Executive Summary
- Deploy from the Mac via `scripts/deploy_remote_devcontainer.sh`; it pushes the branch, ensures the Docker SSH context, copies a public key to the host cache, then triggers the remote rebuild.
- Remote host (`c24s1.ch2`) rebuilds the sandbox (`~/dev/devcontainers/cpp-devcontainer`), stages host `~/.ssh/*.pub`, bakes images with BuildKit, and runs `devcontainer up` with the host agent socket mounted.
- Container lives at `/home/rmanaloto/workspace`, exposes SSH on the configured host port (loopback-only to container 2222), and uses the host agent for outbound GitHub SSH (port 443 fallback).

## Architecture Overview
```
┌─────────────────────────────────────────────────────────────────────┐
│                         Developer's Mac                             │
│  - Repo: ~/dev/github/SlotMap (working copy)                        │
│  - ssh-agent signs requests (private keys stay here)                │
│  - deploy_remote_devcontainer.sh pushes branch + scp's *.pub        │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ SSH (22) + Docker context
┌───────────────────────────▼──────────────────────────────────────────┐
│                     Remote Host: c24s1.ch2                          │
│  - Repo: ~/dev/github/SlotMap                                       │
│  - Sandbox: ~/dev/devcontainers/cpp-devcontainer                    │
│  - Workspace bind source: ~/dev/devcontainers/workspace             │
│  - Key cache: ~/.ssh/*.pub → staged into sandbox/.devcontainer/ssh  │
│  - SSH agent socket: $SSH_AUTH_SOCK (bound into container)          │
│  - Docker daemon + devcontainer CLI                                 │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ devcontainer up
┌───────────────────────────▼──────────────────────────────────────────┐
│                     Container: cpp-devcontainer:local                   │
│  - /home/rmanaloto/workspace (bind mount)                           │
│  - /tmp/ssh-agent.socket (bind of host agent)                       │
│  - ~/.ssh/authorized_keys from staged *.pub files                   │
│  - sshd :2222 published as host :9222                               │
│  - toolchain: clang-21, mold, cmake, vcpkg overlays                 │
└──────────────────────────────────────────────────────────────────────┘

Access pattern: host port 9222 is bound to 127.0.0.1; reach it via SSH tunnel or ProxyJump through the host.
```

## Step-by-Step Workflow

### Phase 1: Local Preparation (Mac)
- Ensure clean tree: `git status --porcelain` must be empty.
- Set defaults in `config/env/devcontainer.env` (host/user/port) and optional `DOCKER_CONTEXT`.
- Run `./scripts/deploy_remote_devcontainer.sh` (env or flags supply host/user/port/workspace). The script:
  - Pushes the current branch to `origin`.
  - Creates/uses the Docker SSH context if `DOCKER_CONTEXT` is set.
  - Copies the chosen public key (default `~/.ssh/id_ed25519.pub`) to the remote key cache (default `~/.ssh` on the host). Legacy full `~/.ssh` sync is disabled unless `SYNC_MAC_SSH=1`.
  - SSHes to the host and invokes `scripts/run_local_devcontainer.sh` with user/uid/gid/workspace args.

### Phase 2: Remote Build & Deploy (c24s1.ch2)
- `run_local_devcontainer.sh` actions:
  - Ensures an SSH agent socket exists; starts one and adds the host key if `SSH_AUTH_SOCK` is absent.
- Recreates the sandbox at `~/dev/devcontainers/cpp-devcontainer` and workspace source at `~/dev/devcontainers/workspace` from the canonical repo (`~/dev/github/SlotMap`).
  - Stages `KEY_CACHE/*.pub` into `.devcontainer/ssh` in both sandbox and workspace; no private keys are copied.
  - Validates `.devcontainer/docker-bake.hcl` and `devcontainer.json`; installs devcontainer CLI `0.80.2` if needed.
  - Bakes `cpp-dev-base:local` if missing, then bakes the requested image (default `cpp-devcontainer:local`; override via env per permutation) with user/uid/gid args.
  - Runs `devcontainer up` with exports:
    - `REMOTE_WORKSPACE_PATH=/home/<user>/dev/devcontainers/workspace`
    - `SSH_AUTH_SOCK` from the host (bind-mounted to `/tmp/ssh-agent.socket`)
    - `DEVCONTAINER_SSH_PORT` (default 9222) published to container port 2222.
  - Prints container status, lists sshd, and attempts an SSH self-test using the host key if present.

### Phase 3: Connectivity & Validation
- Automated check (preferred):  
  `DOCKER_HOST=ssh://rmanaloto@c24s1.ch2 CONFIG_ENV_FILE=config/env/devcontainer.gcc15-clang21.env scripts/verify_devcontainer.sh --require-ssh`
- From the Mac, clear stale host keys if needed: `ssh-keygen -R "[c24s1.ch2]:9222"`.
- Run `./scripts/test_devcontainer_ssh.sh --host c24s1.ch2 --port 9222 --user rmanaloto --key ~/.ssh/id_ed25519 --clear-known-host` (uses ProxyJump by default).
- Manual spot checks from the Mac (ProxyJump):
  ```bash
  ssh -J rmanaloto@c24s1.ch2 -i ~/.ssh/id_ed25519 -p 9222 rmanaloto@127.0.0.1 'echo CONTAINER_OK && hostname && whoami'
  ssh -J rmanaloto@c24s1.ch2 -i ~/.ssh/id_ed25519 -p 9222 rmanaloto@127.0.0.1 'echo $SSH_AUTH_SOCK && ssh -T -p 443 -o Hostname=ssh.github.com git@github.com || true'
  ```
- Convenience SSH helper (cleans known_hosts entry, then connects using env file defaults):
  ```bash
  CONFIG_ENV_FILE=config/env/devcontainer.gcc15-clang22.env scripts/ssh_devcontainer.sh
  ```
- In-container verification:
  ```bash
  echo "$SSH_AUTH_SOCK"            # Expected: /tmp/ssh-agent.socket
  ssh-add -l                       # Should list host-loaded keys
  ssh -T -p 443 -o Hostname=ssh.github.com git@github.com || true
  ```

## Protocol Highlights
- Mac → Remote host: SSH on port 22 for git push + orchestration; authentication uses the Mac-held private key.
- Remote host → Container: devcontainer CLI instructs Docker via the SSH context (if set); bind mounts workspace and agent socket; publishes host port 9222 to container 2222.
- Container → GitHub: uses host SSH agent socket; prefers port 443 (`ssh.github.com:443`) to bypass 22 egress filters.

## Known Risks / Follow-ups
- Host port 9222 binds to `0.0.0.0`; switch to `127.0.0.1:9222` and tunnel from the Mac when ready.
- Legacy full-`~/.ssh` sync (`SYNC_MAC_SSH=1`) remains available but is disabled by default; keep it off to avoid private-key exposure.
- Remote-resident agent (systemd socket) is optional; current flow relies on the host user’s agent started by `run_local_devcontainer.sh`.
