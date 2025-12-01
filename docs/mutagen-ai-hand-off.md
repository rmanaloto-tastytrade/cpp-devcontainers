# Mutagen SSH Agent Issue – AI Hand-off

## Situation
- Goal: Mutagen two-way sync between macOS host and remote devcontainers (c0903s4.ny5/c24s1.ch2) over SSH, validated as part of `verify_devcontainer.sh` (`REQUIRE_MUTAGEN=1`).
- Blocker: `mutagen sync create` fails; agent launch command is malformed.
  - Logged argv (from ssh wrapper):
    ```
    /tmp/.../ssh -oConnectTimeout=5 -oServerAliveInterval=10 -oServerAliveCountMax=1 ssh .mutagen/agents/0.18.1/mutagen-agent synchronizer --log-level=info
    ```
    Host argument becomes literal `ssh`, causing `ssh: Could not resolve hostname ssh`.
  - Subsequent SSH commands (cleanup) use the correct host.
  - Happens even with minimal local tests (`ssh://localhost/tmp`, `localhost:/tmp`).
  - Plain SSH to devcontainers works.

## What’s implemented
- Host setup: `scripts/setup_mutagen_host.sh`
  - Writes `~/.mutagen/slotmap_ssh_config` (ProxyJump, key, port) and minimal `~/.mutagen.yml`; restarts daemon.
- Validation: `scripts/verify_mutagen.sh`
  - Uses scp-style endpoint (`user@127.0.0.1:/path`), logging ssh wrapper (`/tmp/mutagen_ssh_invocations.log`), probes a temp dir, flushes, verifies both directions.
- Devcontainer verify hook: `scripts/verify_devcontainer.sh` runs Mutagen check when `REQUIRE_MUTAGEN=1`.
- Docs: `docs/mutagen-validation.md`, `docs/mutagen-research.md`, `PROJECT_PLAN.md` updated with status, attempts, and next steps.

## Repros
1) Host SSH works:
   - `ssh -F ~/.mutagen/slotmap_ssh_config slotmap-mutagen 'echo ok'` ✅
2) Mutagen fails:
   - `CONFIG_ENV_FILE=config/env/devcontainer.c0903.gcc14-clang21.env REQUIRE_MUTAGEN=1 scripts/verify_devcontainer.sh --require-ssh`
   - Error: `ssh: Could not resolve hostname ssh: nodename nor servname provided`
   - Log file: `/tmp/mutagen_ssh_invocations.log` shows agent host = `ssh`.
3) Minimal local:
   - `mutagen sync create /tmp/foo ssh://localhost/tmp` → same host=`ssh` failure.

## Hypotheses
- Mutagen CLI/daemon constructs agent command incorrectly (possibly a bug/regression in 0.18.1).
- Environment/config isn’t being honored for the agent launch (ignoring `MUTAGEN_SSH_COMMAND`/config when launching agent).

## Next debug steps (suggested)
1) Run `MUTAGEN_LOG_LEVEL=debug mutagen daemon run` in foreground with logging ssh wrapper to capture full argv and environment during agent launch.
2) Try prior Mutagen release (e.g., 0.17.x) to see if bug is 0.18.x-specific.
3) File upstream issue with logs and minimal repro (`mutagen sync create /tmp/foo ssh://localhost/tmp` on macOS 0.18.1) showing host argument becomes `ssh`.
4) If feasible, add a tiny shim that rewrites argv before exec to force correct host (workaround), then re-enable validation.

## Files to review
- `scripts/setup_mutagen_host.sh`
- `scripts/verify_mutagen.sh`
- `scripts/verify_devcontainer.sh` (Mutagen hook)
- `docs/mutagen-validation.md`, `docs/mutagen-research.md`, `PROJECT_PLAN.md`
- Log: `/tmp/mutagen_ssh_invocations.log`
