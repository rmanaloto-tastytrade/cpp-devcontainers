# Remote Devcontainer AI Guide (V2)

**Last Updated:** 2025-12-05
**Purpose:** Guide AI agents through the "Mac Client -> Linux Host" devcontainer workflow, highlighting critical real-world failure modes and required fixes.

---

## 1. Architecture Overview

### Topology

- **Local Client:** macOS (User: `ray.manaloto`)
- **Remote Host:** Linux/Ubuntu AMD EPYC (e.g., `c090s4`)
- **Transport:** Docker over SSH (`DOCKER_HOST=ssh://...`) + Mutagen (file sync)

### Key Components

| Component | Role | Critical File |
| :--- | :--- | :--- |
| **Deploy Script** | Orchestrates the push from Mac to Linux | `scripts/deploy_remote_devcontainer.sh` |
| **Run Script** | Executes on Linux to build/launch Docker | `scripts/run_local_devcontainer.sh` |
| **Matrix Build** | Defines image permutations (gcc14/15, clang21/22) | `.devcontainer/docker-bake.hcl` |
| **Env Configs** | Per-host/per-permutation variables | `config/env/devcontainer.c090s4.*.env` |

### SSH & Connectivity Reference

- **ProxyJump:** Required for Mac to reach the container (which binds to `127.0.0.1` on the Remote Host).
- **SSH Config (`~/.ssh/config`):**

  ```ssh
  Host c090s4
    HostName <ip_or_dns>
    User <remote_user>
    IdentityFile ~/.ssh/tastytrade_key

  # Container connection (example)
  Host slotmap_devconfig
    HostName 127.0.0.1
    Port 9222
    User slotmap
    ProxyJump c090s4
    IdentityFile ~/.ssh/tastytrade_key
  ```

- **Validation Context:**
  - **Remote-Side:** Checks if container is physically running (`docker ps` on Linux host).
  - **Client-Side:** Checks accessibility (`ssh` from Mac). *Always validate locally (Mac) to ensure end-to-end connectivity.*

---

## 2. Critical "Gotchas" & Known Failure Modes

### 🛑 Issue 1: "Cold Start" Volume Permissions (Permission Denied)

- **Symptom:** `postCreateCommand` fails with `mkdir: cannot create directory '/cppdev-cache/...': Permission denied`
- **Root Cause:** On a clean host, Docker creates the named volume `cppdev-cache` as `root:root`. The container runs as `slotmap` (UID 1000) and cannot write to it.
- **Required Fix:** The `run_local_devcontainer.sh` script **must** proactively `chown` the volume before `devcontainer up`.

  ```bash
  # Patch for scripts/run_local_devcontainer.sh
  docker run --rm -v "${DEVCONTAINER_CACHE_VOLUME}:/data" --user root "${DEV_IMAGE}" chown -R "${CONTAINER_UID}:${CONTAINER_GID}" /data
  ```

### 🛑 Issue 2: SSH Key Propagation (Public vs Private)

- **Symptom:** Remote host cannot be accessed, or container cannot pull from GitHub (`Permission denied (publickey)`).
- **Root Cause:** `scripts/deploy_remote_devcontainer.sh` previously defaulted to `id_ed25519.pub`. When config pointed to a *private* key variable (`~/.ssh/tastytrade_key`), the script tried to SCP the private key content as the public key, or failed to find it.
- **Required Fix:** Logic to automatically append `.pub` to the configured key path when staging keys for the remote.

### 🛑 Issue 3: `ty` Installation 404

- **Symptom:** `docker build` fails at `RUN ... ty ...`
- **Root Cause:** The URL `https://astral.sh/ty/install.sh` returns 404.
- **Required Fix:** Remove or comment out the `ty` installation in `.devcontainer/Dockerfile`.

### 🛑 Issue 4: Agent Shell Instability (Exit Code 130)

- **Symptom:** Automated git commands or script executions hang and fail with `Exit Code 130`.
- **Constraint:** The AI agent may be effectively "read-only" on the terminal.
- **Workaround:** **User must manually execute** `git commit` and `git push` to propagate fixes to the remote host. The remote host pulls via `git`, so local uncommitted changes are ignored!

---

## 3. Workflow Checklist for Agents

### Phase 1: Preparation

1. **Check Env:** Identify target host from `config/env/devcontainer.<host>.*.env`.
2. **Verify ssh-config:** Ensure `~/.ssh/config` allows passwordless `ssh <host>`.

### Phase 2: Deployment (Optimized via Rsync)

**Note:** The deployment script uses `rsync` to mirror your local folder (including potential uncommitted fixes) to the remote host. You do **NOT** need to `git commit` or `git push` for changes to take effect on the remote devcontainer.

1. **Deploy:**

    ```bash
    set -a && source config/env/devcontainer.<host>.<variant>.env && set +a && ./scripts/deploy_remote_devcontainer.sh
    ```

### Phase 3: Verification (Automated)

**Recommended:** Use the fully automated matrix verification script.

```bash
# 1. Ensure script is executable (Manual Step)
chmod +x scripts/verify_remote_devcontainer_matrix.sh

# 2. Run Automation
./scripts/verify_remote_devcontainer_matrix.sh
```

### Phase 4: Verification (Manual / Debugging)

If the automated script fails, use these manual steps:

1. **Log Analysis:** Watch local logs for `Resolving public key...` (indicates fix applied) and `Container started`.
2. **Remote Check (SSH to Host):** `ssh <host> 'docker ps'` to confirm container status.
3. **Connectivity Check (SSH to Container):**
    - Use ProxyJump (e.g., `-J <host>`):

    ```bash
    ssh -J <user>@<host> -p <port> <container_user>@127.0.0.1 "echo ACCESS_OK"
    ```

4. **Volume Check:** `ssh -J <user>@<host> -p <port> <container_user>@127.0.0.1 "touch /cppdev-cache/write_test"`

---

## 4. Suggested Improvements (Future Work)

2. **Native SSH Agent Forwarding:** Reliance on copying keys is fragile. Ensure `SSH_AUTH_SOCK` mount works reliably across macOS/Linux boundaries.
3. **Artifact Independence:** Modify deploy script to `rsync` the *current local folder* instead of `git pull`ing on remote. This would allow deploying uncommitted dirty-tree fixes (crucial for debugging).
