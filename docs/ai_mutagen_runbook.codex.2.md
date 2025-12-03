# AI Agent Runbook — Mutagen + Remote Devcontainer (Codex 2)

Objective: guide an AI agent to fix and harden macOS → remote devcontainer sync via Mutagen using current repo state and modern Docker/devcontainer/Mutagen/SSH practices.

## Baseline facts
- Workspace mount: `/home/<DEVCONTAINER_USER>/workspace` (see `.devcontainer/devcontainer.json`).
- SSH: container sshd on 2222; host forwards `127.0.0.1:${DEVCONTAINER_SSH_PORT:-9222}` → container:2222.
- Mutagen target version: `0.18.1` (pinned in `.devcontainer/Dockerfile`, checked in `scripts/verify_devcontainer.sh`).
- Current bug: `mutagen sync create` builds an agent command with host literal `ssh` → `ssh: Could not resolve hostname ssh` even though plain SSH works. Repro even with `ssh://localhost/tmp`.
- Mutagen check is optional: `scripts/verify_devcontainer.sh` runs it only when `REQUIRE_MUTAGEN=1`.

## Files to read first (in this order)
1) `.devcontainer/devcontainer.json` — port mapping, workspace mount, `remoteUser`.
2) `.devcontainer/Dockerfile` — Mutagen install block (`MUTAGEN_VERSION`), SSH client presence.
3) `scripts/setup_mutagen_host.sh` — writes `~/.mutagen/cpp-devcontainer_ssh_config`, minimal `~/.mutagen.yml`, ssh/scp wrappers, restarts daemon.
4) `scripts/verify_mutagen.sh` — probe session creation/flush/validate.
5) `scripts/verify_devcontainer.sh` — Mutagen gate (`REQUIRE_MUTAGEN`), tool checks.
6) `docs/mutagen-validation.md`, `docs/mutagen-ai-hand-off.md`, `docs/mutagen-research.md`, `docs/mutagen_sync.md` — status and context.
7) `config/env/*.env` — host/user/port/key defaults; choose the env matching your target host.
8) Log (if present): `/tmp/mutagen_ssh_invocations.log` from the ssh wrapper.

## Reproduce the failure (macOS)
```bash
# Prepare host-side config/wrapper (adjust env file as needed)
CONFIG_ENV_FILE=config/env/devcontainer.env scripts/setup_mutagen_host.sh

# In terminal A: run daemon in foreground to capture argv
MUTAGEN_LOG_LEVEL=debug \
MUTAGEN_SSH_COMMAND=$HOME/.mutagen/bin/ssh \
MUTAGEN_SSH_PATH=$HOME/.mutagen/bin \
mutagen daemon run

# In terminal B: trigger the probe
CONFIG_ENV_FILE=config/env/devcontainer.env scripts/verify_mutagen.sh
```
Expected: failure with `ssh: Could not resolve hostname ssh`; log shows extra `ssh` token where host should be.

## Fix and experimentation
1) **Force explicit SSH command/path**
   Write `~/.mutagen.yml`:
   ```yaml
   sync:
     defaults:
       ssh:
         command: "/usr/bin/ssh -F $HOME/.mutagen/cpp-devcontainer_ssh_config"
         path: "$HOME/.mutagen/bin"
   ```
   Restart daemon:
   ```bash
   MUTAGEN_SSH_COMMAND=$HOME/.mutagen/bin/ssh \
   MUTAGEN_SSH_PATH=$HOME/.mutagen/bin \
   mutagen daemon restart
   ```

2) **Re-test probe**
   Rerun `scripts/verify_mutagen.sh` with the same `CONFIG_ENV_FILE`. Check `mutagen sync list --long <session>` for `Status: Watching/Connected`, zero retries/backoff/conflicts, probes on both ends.

3) **Version A/B**
   If still broken, try aligned host/container versions (e.g., host installs mutagen 0.17.x; container baked or overlayed with same). Re-run probe, capture argv/logs.

4) **Collect evidence**
   Save failing argv from `/tmp/mutagen_ssh_invocations.log` and daemon debug output. Minimal repro: `mutagen sync create /tmp/foo ssh://localhost/tmp`.

5) **Harden workflow once fixed**
   - Run `REQUIRE_MUTAGEN=1 scripts/verify_devcontainer.sh --require-ssh` for all env files.
   - Add/finish a helper `scripts/mutagen_sync.sh` to wrap create/pause/resume/terminate with ignores (`.git`, `build/`, `cmake-build-*`, `logs/`, `vcpkg_installed/`) derived from `CONFIG_ENV_FILE`.
   - Ensure SSH config uses `StrictHostKeyChecking=accept-new`, `IdentitiesOnly=yes`, correct key, ProxyJump per env.
   - Avoid overlapping Mutagen sessions on same paths.

## Validation criteria
- `scripts/verify_mutagen.sh` passes: probes present both directions; `mutagen sync list --long` shows connected/healthy; session terminates and cleans probes.
- `scripts/verify_devcontainer.sh --require-ssh` with `REQUIRE_MUTAGEN=1` passes tool + Mutagen checks for target env.
- Host/container Mutagen versions match; ssh wrapper/command persists across daemon restarts.

## Deliverables for the agent
- Brief summary of changes made, commands run, logs captured.
- If unresolved, include failing argv, daemon debug excerpt, versions tested, and recommended next step (e.g., upstream issue).
