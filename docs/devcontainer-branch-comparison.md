# Devcontainer Comparison: security-fixes-phase1 vs modernization.20251118

This note compares the devcontainer setup between the remote branch `security-fixes-phase1` and the current branch `modernization.20251118`, focusing on SSH exposure, key handling, and helper tooling.

| Aspect | security-fixes-phase1 | modernization.20251118 | Considerations |
| --- | --- | --- | --- |
| SSH port binding | `-p 9222:2222` (0.0.0.0) | `127.0.0.1:${DEVCONTAINER_SSH_PORT:-9222}:2222` | Current branch is hardened; keep loopback binding. |
| SSH auth mount | Bind `${localEnv:REMOTE_SSH_SYNC_DIR}` → `/home/${user}/.ssh` (host .ssh into container) | Bind `${localEnv:SSH_AUTH_SOCK}` → `/tmp/ssh-agent.socket`; no .ssh mount | Current branch avoids private-key mount; keep. |
| `containerEnv` SSH | No `SSH_AUTH_SOCK` | `SSH_AUTH_SOCK=/tmp/ssh-agent.socket` | Already aligned with agent usage. |
| `post_create.sh` (authorized_keys) | Backs up existing `authorized_keys`, warns if private keys in `~/.ssh`, installs staged `*.pub` | Installs staged `*.pub`; simpler backups | Could borrow the backup/warning behavior without reintroducing key mounts. |
| `post_create.sh` (ssh config) | Strips `UseKeychain`, backs up config; enforces GitHub SSH over 443 | Strips `UseKeychain`, adds `CanonicalizeHostname no` and `StrictHostKeyChecking accept-new` for GitHub 443 | Current branch is stricter; keep. |
| GitHub SSH egress | Port 443 fallback | Port 443 fallback + canonicalization/hostkey options | Current branch already stronger. |
| SSH config helper | None | `scripts/generate_cpp_devcontainer_ssh_config.sh` (reads env file, writes `~/.ssh/cpp-devcontainer.conf`, supports `--env-file/--output/--proxy-user`, includes `~/.ssh/config`, resolves canonical host) | Keep helper; enables per-env config for multiple devcontainers. |
| Docs | No SSH generator doc; includes CRITICAL_FINDINGS/AI_AGENT_CONTEXT; diagrams updated | Updated workflows with loopback binding + generator docs | If desired, cherry-pick CRITICAL_FINDINGS for reference; otherwise current docs cover new flow. |
| Security posture | Keys in container via bind mount; port exposed on all interfaces | Keys stay on host (agent), loopback-only port | Current branch is more secure by default. |

Potential borrow (non-breaking):
- Add the `authorized_keys` backup/warning from `security-fixes-phase1` into current `post_create.sh` while keeping agent-only auth.***
