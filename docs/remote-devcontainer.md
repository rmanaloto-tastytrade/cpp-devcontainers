## Remote Devcontainer Workflow

This document describes how the SlotMap devcontainer is deployed on a shared Linux host while source control stays clean. It captures the directory layout, the scripts that orchestrate the flow, troubleshooting tips, and a visual workflow diagram.

### Goals
- Keep `/home/<user>/dev/github/SlotMap` as a clean clone that mirrors Git history.
- Build and run the devcontainer in a sandbox (`~/dev/devcontainers/cpp-devcontainer`) that is recreated on every deployment.
- Use the remote host user (example `rmanaloto`) as the devcontainer user (UID/GID aligned with host).
- Rely on the remote host’s SSH agent/keys; only public keys are staged for container `authorized_keys` (no Mac private keys are copied).
- Provide a single local command (`./scripts/deploy_remote_devcontainer.sh`) that pushes code, copies keys, and rebuilds the remote container end-to-end.
- Default GitHub SSH inside the container to port 443 (`ssh.github.com`) because many data-center networks block port 22; see GitHub docs “Using SSH over the HTTPS port”.

### Directory Layout
| Path | Description |
| --- | --- |
| `~/dev/github/SlotMap` | Clean git clone on the remote host. No untracked files; only `git pull` and script execution happen here. |
| `~/.ssh` | Host SSH directory; public keys staged into sandbox `.devcontainer/ssh` for container `authorized_keys`. Private keys stay on the host/agent. |
| `~/dev/devcontainers/cpp-devcontainer` | Sandbox used by `run_local_devcontainer.sh`. Recreated from the clean repo and includes `.devcontainer/ssh/*.pub` copied from host `~/.ssh` (public keys only). |
| `/workspaces/SlotMap` | Path inside the container where the sandbox is mounted. `post_create.sh` copies staged keys into `/home/<dev-user>/.ssh/authorized_keys`. |

### Workflow Diagram
```mermaid
flowchart TD
    A[Mac laptop\n./scripts/deploy_remote_devcontainer.sh] -->|git push| B(GitHub repo)
    A -->|ssh remote| D[Remote host shell]
    D -->|run_local_devcontainer.sh| E[/~/dev/devcontainers/cpp-devcontainer sandbox/]
    E -->|devcontainer up| F[(Docker container\nhost-matching user + sshd)]
    F -->|port 2222 published as ${DEVCONTAINER_SSH_PORT:-9222}| A
```

### Required Local Checks Before Deploy
1. Run `./scripts/pre_commit.sh` locally. It stays fast and validates:
   - `scripts/check_docker_bake.sh` – prints and dry-runs `.devcontainer/docker-bake.hcl` to ensure targets/args parse before building.
   - `scripts/check_devcontainer_config.sh` – validates `devcontainer.json`/`*.jsonc` structure (skips if Docker/CLI missing).
   - `hadolint` on `.devcontainer/Dockerfile` (warnings allowed) to catch Dockerfile issues early.
   - `shellcheck --severity=warning scripts/*.sh` to lint helper scripts.
2. Only commit/push after these pass. If any fail, fix locally first.
3. Push and watch GitHub Actions (linters/validators) until they go green. Do not trigger the remote rebuild until CI is clean.
4. After CI is green, run `./scripts/deploy_remote_devcontainer.sh --remote-host <host> --remote-user <user>` (host/user/port configurable via env/args) to rebuild the devcontainer on the remote host.

### Detailed Steps
1. **Local machine (Mac)**  
   Run `./scripts/deploy_remote_devcontainer.sh`. The script:
   - Verifies the working tree is clean and pushes the current branch to `origin`.
   - SSHes into the remote host and invokes `scripts/run_local_devcontainer.sh` (SSH keys come from the remote host user; Mac keys are not copied).

2. **Remote host (`run_local_devcontainer.sh`)**  
   - Removes `~/dev/devcontainers/cpp-devcontainer` and re-creates it.  
   - `rsync`s the clean repo into the sandbox.  
   - Copies every `*.pub` from `~/.ssh` into `sandbox/.devcontainer/ssh` (host public keys only) for container `authorized_keys`.  
   - Calls `devcontainer up --workspace-folder ~/dev/devcontainers/cpp-devcontainer --remove-existing-container --build-no-cache`.

3. **Devcontainer lifecycle**  
   - Docker builds `.devcontainer/Dockerfile` (LLVM 21 toolchain, Ninja, mold, MRDocs, IWYU, etc.).  
   - Feature `ghcr.io/devcontainers/features/sshd` starts an SSH server that listens on container port `2222`. `runArgs` map host `9222` to container `2222`.  
   - `.devcontainer/scripts/post_create.sh` fixes permissions, copies staged `.pub` files to `/home/<dev-user>/.ssh/authorized_keys`, and runs `cmake --preset clang-debug`.  
   - The deploy script logs output under `logs/deploy_remote_devcontainer_<timestamp>.log` for later review.

4. **Connecting from the laptop**  
   - Port is bound to `127.0.0.1:<port>` on the host. Use a tunnel or ProxyJump, e.g. `ssh -J <remote-username>@<host> -i ~/.ssh/id_ed25519 -p <port> <remote-username>@127.0.0.1`. The username equals the Linux account on the host because build args set the devcontainer user accordingly.  
   - CLion or VS Code can reuse the same host/port via a jump configuration.  
   - GitHub SSH from inside the container uses port 443 (Host github.com -> ssh.github.com:443) to avoid egress blocks on port 22.

### Troubleshooting & Validation Checklist
| Check | Command |
| --- | --- |
| Confirm container is running and exposing the port | `ssh ${REMOTE_USER}@${REMOTE_HOST} "docker ps --filter label=devcontainer.local_folder=/home/${REMOTE_USER}/dev/devcontainers/cpp-devcontainer --format 'table {{.ID}}\t{{.Ports}}\t{{.Names}}'"` |
| Inspect staged keys inside the container | `docker exec -u <remote-username> <container> ls -l /home/<remote-username>/.ssh/authorized_keys` |
| View SSHD logs | `docker exec -u root <container> tail -n 100 /var/log/auth.log` |
| Test GitHub SSH (22 then 443) | `ssh -T -o BatchMode=yes git@github.com || ssh -T -p 443 -o Hostname=ssh.github.com -o BatchMode=yes git@github.com` |
| Clean up stuck containers/images | `docker rm -fv $(docker ps -aq --filter label=devcontainer.local_folder=/home/${REMOTE_USER}/dev/devcontainers/cpp-devcontainer)` and `docker system prune -af --volumes` |
| Validate toolchain bits (cmake/ninja/IWYU/etc.) | `docker exec -u <remote-username> <container> include-what-you-use --version` |
| Validate GCC from toolchain PPA | `docker exec -u <remote-username> <container> gcc-14 --version` |
| Confirm caching/search helpers | `docker exec -u <remote-username> <container> ccache --version && sccache --version && rg --version` |
| Rebuild sandbox manually on remote | `cd ~/dev/github/SlotMap && ./scripts/run_local_devcontainer.sh` |

If SSH fails with `Connection reset by peer`, verify that `/home/<remote-username>/.ssh/authorized_keys` exists and the runArgs publish `127.0.0.1:${DEVCONTAINER_SSH_PORT:-9222}:2222` (use a tunnel or ProxyJump).

### Notes
- The sandbox copy is refreshed on every deployment, so local edits must be committed/pushed before running the helper.
- Multiple developers can share the same remote host: each user’s host `~/.ssh/*.pub` is staged into their sandbox; scripts remain parameterized (`--remote-user`, `--ssh-key`, etc.).
- `logs/` contains timestamped execution transcripts for traceability. Include them in bug reports or when auditing remote builds.
- GitHub SSH fallback to port 443 is configured per GitHub guidance (“Using SSH over the HTTPS port”) and we prefer agent forwarding when possible (“Using SSH agent forwarding”).
- We disable SSH hostname canonicalization for `github.com` inside the container to avoid DNS suffix rewrites (e.g., `github.com.tastyworks.com`), which break GitHub SSH; see OpenSSH `ssh_config(5)` for `CanonicalizeHostname`.
- We set `StrictHostKeyChecking accept-new` for `github.com` in-container so the first connect on port 443 can add the host key without an interactive prompt; see OpenSSH `ssh_config(5)` for the option semantics.
- The container binds the host SSH agent socket (`SSH_AUTH_SOCK`) for outbound GitHub SSH; ensure the agent is running and keys are loaded on the remote host before deploying.

For details on the helper scripts themselves see `scripts/deploy_remote_devcontainer.sh` (local) and `scripts/run_local_devcontainer.sh` (remote). Both scripts print verbose status messages so you can follow the entire workflow from your terminal or CI logs.
