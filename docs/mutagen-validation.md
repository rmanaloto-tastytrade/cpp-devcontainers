# Mutagen Validation for Remote Devcontainers

## Purpose
- Ensure file sync works end-to-end between a local macOS workspace and a remote devcontainer running on a host (e.g., c090s4.ny5) with SSH port-forwarded access.
- Make Mutagen sync a mandatory, automated check so devcontainers are only “green” when two-way file propagation succeeds.

## How We Validate
1) Start Mutagen daemon locally (script does this if needed).
2) Discover connection details from `CONFIG_ENV_FILE` (DEVCONTAINER_REMOTE_HOST/USER/SSH_PORT/SSH_KEY, CONTAINER_USER).
3) Create a temporary two-way-resolved Mutagen session pointing at a small probe directory inside the workspace:
   - Local: `<repo>/.mutagen_probe`
   - Remote: `/home/<CONTAINER_USER>/workspace/.mutagen_probe`
   - SSH uses `-J <REMOTE_USER>@<REMOTE_HOST>` because the devcontainer SSH port is bound to 127.0.0.1 on the remote host.
4) Drop probe files on both sides, flush, and assert both files appear on both ends.
5) Print `mutagen sync list --verbose` for the session, then terminate the session and clean up the probe dirs.

## Automation
- Script: `scripts/verify_mutagen.sh`
  - Reads `CONFIG_ENV_FILE` (defaults to `config/env/devcontainer.env`).
  - Requires Mutagen 0.18+ locally and the SSH key defined in the env file.
  - Fails if probes don’t propagate or if the session reports errors.
- Integrated hook: `scripts/verify_devcontainer.sh` will run Mutagen validation when `REQUIRE_MUTAGEN=1` is set in the environment.

## Quick Manual Run
```bash
# from repo root
CONFIG_ENV_FILE=config/env/devcontainer.c090s4.gcc14-clang21.env \
REQUIRE_MUTAGEN=1 \
scripts/verify_devcontainer.sh --require-ssh
```
This will:
- Verify tools/compilers via Docker/SSH; then
- Run the Mutagen probe session; fail if sync is not healthy.

## What “pass” looks like
- `mutagen sync list --verbose <session>` shows `Status: Watching/Connected`, no retries/backoff, no conflicts.
- Probe files from both sides exist on both ends after a flush.
- Session terminates cleanly and probe directories are removed.

## Notes
- The SSH connection uses ProxyJump to the remote host because the devcontainer ports are published on 127.0.0.1 of the host. Host names are suffixed automatically with `MUTAGEN_DOMAIN_SUFFIX` (default `tastyworks.com`) when running `scripts/setup_mutagen_host.sh`; set `DEVCONTAINER_REMOTE_HOST` or `MUTAGEN_PROXY_HOST` to a fully qualified host if needed.
- The probe directories are transient and ignored after the script exits.
- If you hit `ssh: Could not resolve hostname ssh` during the Mutagen step, clear any stale local tunnels and re-run with `MUTAGEN_LOG_LEVEL=debug` to capture the underlying ssh invocation; the failure indicates the SSH call to the devcontainer did not complete.

## Current Debug Status (pending fix)
- Symptom: `mutagen sync create` fails with `ssh: Could not resolve hostname ssh: nodename nor servname provided`.
- Logging wrapper shows Mutagen constructs the agent launch as:
  ```
  .../ssh -oConnectTimeout=5 ... ssh .mutagen/agents/0.18.1/mutagen-agent synchronizer ...
  ```
  The host argument becomes literal `ssh`, so DNS lookup fails before reaching the container.
- Plain SSH to the devcontainer (via ProxyJump or a local tunnel) succeeds; the issue is specific to how Mutagen builds its ssh command.
- Next steps to resolve:
  1) Run the Mutagen daemon in the foreground with `MUTAGEN_LOG_LEVEL=debug` and a logging ssh wrapper to capture the exact argv Mutagen builds.
  2) Force ssh config via `~/.mutagen.yml` (e.g., `sync.ssh.command: "/usr/bin/ssh -F <cfg>"`) or a PATH-wrapped `ssh` binary to ensure Mutagen doesn’t prepend an extra `ssh` token.
  3) Once agent handshake succeeds, rerun `scripts/verify_devcontainer.sh --require-ssh` with `REQUIRE_MUTAGEN=1` across all env files.

## Reference Notes (from upstream docs and examples)
- Mutagen transports:
  - Defaults to `ssh` with the first non-option token as the host; `MUTAGEN_SSH_COMMAND` or `sync.ssh.command` in `~/.mutagen.yml` can override.
  - Avoid embedding a literal `ssh` token in the host position; if wrapping ssh, ensure the first non-option is `%h`.
  - Agent path is copied to remote as `.mutagen/agents/<version>/mutagen-agent` and launched via ssh.
- Useful flags (per docs/tutorial):
  - `--sync-mode=two-way-resolved`, `--watch-mode=portable`, `--ignore-vcs`, `--name <session>`.
  - `MUTAGEN_LOG_LEVEL=debug` to diagnose handshake and agent launch.
- macOS specifics:
  - File monitoring uses fsevents; falls back to polling if unavailable (see mutagen-io/fsevents).
  - When using Docker Desktop, alternative sync options exist (Docker “synchronized file sharing”); Mutagen can coexist but should be single source of truth per mount.
- Examples repos reviewed:
  - mutagen-io/mutagen-compose: shows using mutagen with compose via a sidecar sync container.
  - mutagen-io/example-voting-app: demonstrates devloop with mutagen-managed volumes.
  - mutagen-io/mutagen: CLI code and tests; ssh transport expects host argument immediately after options.
  - mutagen-io/fsevents: macOS watcher implementation details.
  - Datanovia tutorial series: reiterates two-way-resolved mode, flushing, and conflict handling.

## Action items for this repo
- Add `~/.mutagen.yml` pointing to a controlled ssh command (`ssh -F ~/.mutagen/cpp-devcontainer_ssh_config`), and keep the cfg minimal (Host cpp-devcontainer-mutagen with ProxyJump baked in). Host-side helper: `scripts/setup_mutagen_host.sh`.
- Run `mutagen daemon run` or restart after config changes to confirm host/argv are correct (logging wrapper optional).
- After fixing the ssh command construction, re-enable automated validation (`REQUIRE_MUTAGEN=1`) in `verify_devcontainer.sh` for all permutations.

## What we already tried (chronological)
- Local tunnel approach (deprecated): opened local port to devcontainer, used `ssh://127.0.0.1:<port>`; Mutagen still launched agent with host `ssh`.
- Host-side config approach (current):
  - `scripts/setup_mutagen_host.sh` writes `~/.mutagen/cpp-devcontainer_ssh_config` (ProxyJump to remote host, key, port) and minimal `~/.mutagen.yml`.
  - `scripts/verify_mutagen.sh` uses a logging ssh wrapper and scp-style endpoint (`user@127.0.0.1:/path`).
  - Result: agent launch still logs host `ssh`; subsequent commands (cleanup) use the correct host.
- Minimal local test: `mutagen sync create /tmp/foo ssh://localhost/tmp` and `mutagen sync create /tmp/foo localhost:/tmp` both fail with host `ssh`.

## Upstream issue search
- Searched mutagen-io/mutagen issues (via gh). No existing issue matches “host becomes ssh”. Related but different: #495 (cannot find ssh in PATH), #531 (server magic incorrect). Likely need a new upstream issue with our logs/repro.
