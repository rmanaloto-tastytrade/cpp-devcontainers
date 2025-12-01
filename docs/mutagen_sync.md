# Mutagen-Based Near-Real-Time Sync (macOS → Remote Devcontainer)

**Goal:** Provide near real-time file sync from a macOS client to a remote devcontainer, keeping the Mac as a “thin terminal” while all builds and tools run in the remote container.

## What Mutagen Does
- Runs a lightweight agent on both ends of an SSH connection and synchronizes changes bi-directionally (or one-way) with low latency.
- Watches the local tree, batches file changes, and applies deltas on the remote side; tolerates flaky connections and resumes automatically.
- Preserves permissions/mtimes better than SSHFS; avoids performance issues common to network filesystems.
- Uses existing SSH transport; can be layered over ProxyJump to reach the container’s sshd.

## Why Use It Here
- We already bind a workspace on the remote host into the container; Mutagen will replace manual git/rsync pushes for faster edit→build cycles from macOS.
- Keeps the container as the execution locus (build/tests/tools) while macOS remains a keyboard/display endpoint.
- Avoids SSHFS/Mutagen conflicts by relying solely on Mutagen for sync; no double-mounting.

## Proposed Usage Pattern
1) Ensure the devcontainer is running and exposes sshd on loopback: `127.0.0.1:<port> -> container:2222` (as configured in `devcontainer.json`).
2) Add an SSH config entry that ProxyJumps through the remote host to the container:
   ```sshconfig
   Host cpp-devcontainer
       HostName 127.0.0.1
       Port <DEVCONTAINER_SSH_PORT>
       User <CONTAINER_USER>
       IdentityFile ~/.ssh/github_key
       ProxyJump <REMOTE_USER>@<REMOTE_HOST>
       StrictHostKeyChecking accept-new
   ```
3) Start a Mutagen session from macOS pointing to the container via SSH:
   ```bash
   mutagen sync create \
    --name cpp-devcontainer-sync \
     --ignore-vcs \
     --symlink-mode=posix-raw \
     --default-file-mode=0644 \
     --default-directory-mode=0755 \
     ~/dev/github/SlotMap \
    cpp-devcontainer:/home/<CONTAINER_USER>/workspace
   ```
4) Manage the session:
  - `mutagen sync list cpp-devcontainer-sync`
  - `mutagen sync pause/resume cpp-devcontainer-sync`
  - `mutagen sync terminate cpp-devcontainer-sync`

## Mutagen Availability in the Devcontainer
- The devcontainer image now installs `eget v1.3.4` and `mutagen v0.18.1` at build time (via GitHub releases) into `/usr/local/bin` (`mutagen` and `mutagen-agent`).
- This keeps Mutagen ready inside the container for agent operations; macOS-side Mutagen still runs locally to initiate sessions.
- All GitHub binary installs going forward should use `eget` to enforce consistent, pinned downloads.

## Configuration Notes
- **Ignores:** Add `.git`, build dirs (`build/`, `cmake-build-*`, `logs/`, `vcpkg_installed/`) to reduce churn.
- **Symlinks:** Use `--symlink-mode=posix-raw` to avoid macOS-to-Linux translation issues.
- **Case sensitivity:** macOS is case-insensitive; avoid files that differ only by case.
- **Known hosts:** Our scripts already clear container hostkeys; ensure the SSH config uses `StrictHostKeyChecking=accept-new` to limit prompts.
- **One session per workspace:** Avoid overlapping sessions on the same paths to prevent conflicts.

## Optional Automation (Future)
- A helper script (e.g., `scripts/mutagen_sync.sh`) could wrap `create|pause|resume|terminate|status`, inject ignores, and derive host/user/port from `CONFIG_ENV_FILE`.
- A small doc note can live alongside this file once the helper exists.

## Fit With Existing Workflow
- Complements our remote-only execution model: code is edited locally, synced live, and built/tested inside the remote devcontainer.
- Reuses the existing SSH exposure and ProxyJump pattern; no changes needed to devcontainer.json or Dockerfile.
- Keeps `/usr/local` tool layout untouched; Mutagen only syncs sources.
