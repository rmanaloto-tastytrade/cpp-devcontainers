# Current Workflow: Remote Devcontainer Architecture

**Last Updated:** 2025-01-23
**Status:** Production (with known security issues)
**Audience:** Human operators and AI agents

> Note: Host/user/port values mentioned below (e.g., c24s1, 9222, rmanaloto) are examples only. Use your own `DEVCONTAINER_REMOTE_HOST/DEVCONTAINER_REMOTE_USER/DEVCONTAINER_SSH_PORT` values when running scripts.

## Update (2025-01-23)
- Devcontainer user is the remote host user (`rmanaloto`), not the Mac user.
- Mac private keys are no longer synced; only host `~/.ssh/*.pub` are staged for container `authorized_keys`.
- Outbound GitHub SSH from the container uses the host SSH agent socket bind and port 443 fallback (`ssh.github.com:443`), not bind-mounted private keys.
- Sections below that mention `~/devcontainers/ssh_keys` or syncing Mac `~/.ssh` describe the old flow and should be treated as legacy.

## Executive Summary

This document describes the **complete** current workflow for deploying and connecting to a remote devcontainer for the SlotMap project. It includes all machines, protocols, security mechanisms, and data flows.

**Key Components:**
- **Local Machine:** Developer's Mac (laptop)
- **Remote Host:** (example) `c24s1.ch2` (Ubuntu 24.04 server)
- **Container:** Docker devcontainer running on remote host
- **Protocols:** SSH, Docker Remote API (via SSH tunnel), rsync

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Developer's Mac                              │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ Local Files:                                               │     │
│  │  - ~/dev/github/SlotMap (working copy)                     │     │
│  │  - ~/.ssh/id_ed25519 (private key) ⚠️                      │     │
│  │  - ~/.ssh/id_ed25519.pub (public key)                      │     │
│  │  - ~/.ssh/config (SSH client config)                       │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ Running Processes:                                         │     │
│  │  - git (version control)                                   │     │
│  │  - ssh-agent (manages keys)                                │     │
│  │  - ssh client (connects to remote)                         │     │
│  │  - rsync (syncs files/keys) ⚠️                             │     │
│  └────────────────────────────────────────────────────────────┘     │
└───────────────────────────┬───────────────────────────────────────────┘
                            │
                            │ SSH (port 22)
                            │ + rsync over SSH
                            │
┌───────────────────────────▼───────────────────────────────────────────┐
│                    Remote Host: (example) c24s1.ch2                   │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ Remote Files:                                              │     │
│  │  - ~/dev/github/SlotMap (canonical repo)                   │     │
│  │  - ~/dev/devcontainers/SlotMap (sandbox copy)              │     │
│  │  - ~/dev/devcontainers/workspace (bind mount source)       │     │
│  │  - ~/devcontainers/ssh_keys/ (synced keys) ⚠️              │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ Running Processes:                                         │     │
│  │  - Docker daemon (manages containers)                      │     │
│  │  - devcontainer CLI (orchestrates build/run)               │     │
│  │  - ssh-agent (optional, for Remote-Resident pattern)      │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │           Docker Container: devcontainer:local             │     │
│  │                                                            │     │
│  │  Exposed Ports:                                           │     │
│  │    Container:2222 → Host:9222 (SSH server)               │     │
│  │                                                            │     │
│  │  Bind Mounts:                                             │     │
│  │    Host: ~/dev/devcontainers/workspace                    │     │
│  │      → Container: /home/rmanaloto/workspace               │     │
│  │    Host: ~/devcontainers/ssh_keys ⚠️                       │     │
│  │      → Container: /home/rmanaloto/.ssh                    │     │
│  │                                                            │     │
│  │  Volume Mounts:                                           │     │
│  │    slotmap-vcpkg → /opt/vcpkg/downloads                   │     │
│  │                                                            │     │
│  │  Running Services:                                        │     │
│  │    - sshd (listening on :2222)                            │     │
│  │    - Development tools (clang-21, cmake, vcpkg, etc.)     │     │
│  └────────────────────────────────────────────────────────────┘     │
└───────────────────────────┬───────────────────────────────────────────┘
                            │
                            │ SSH (port 9222 → container:2222)
                            │
┌───────────────────────────▼───────────────────────────────────────────┐
│                    Developer's Mac (SSH Client)                       │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ SSH Connection:                                            │     │
│  │  ssh -i ~/.ssh/id_ed25519 -p 9222 rmanaloto@c24s1.ch2 (example)    │     │
│  │                                                            │     │
│  │ IDE Integration:                                          │     │
│  │  - CLion Remote Development                                │     │
│  │  - VS Code Remote SSH                                      │     │
│  └────────────────────────────────────────────────────────────┘     │
└───────────────────────────────────────────────────────────────────────┘

Legend:
  ⚠️ = Security issue (private keys exposed)
```

---

## Step-by-Step Workflow

### Phase 1: Local Preparation (Mac)

**Script:** `scripts/deploy_remote_devcontainer.sh`
**Execution Context:** Developer's Mac

#### Step 1.1: Validate Local State
```bash
# Check working tree is clean
git status --porcelain
# Must be empty or script exits
```

#### Step 1.2: Push Current Branch
```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "$CURRENT_BRANCH"
```
**Purpose:** Ensure remote host can pull latest changes

#### Step 1.3: Sync SSH Keys to Remote (⚠️ SECURITY ISSUE)
```bash
rsync -e "ssh -o StrictHostKeyChecking=accept-new" \
      -av --chmod=F600,D700 \
      --rsync-path="mkdir -p ~/devcontainers/ssh_keys && rsync" \
      ~/.ssh/ \
      rmanaloto@c24s1.ch2:~/devcontainers/ssh_keys/
```

**What Gets Synced:**
- ✅ `id_ed25519.pub` (public key - safe)
- ⚠️ `id_ed25519` (private key - **RISK**)
- ⚠️ `known_hosts` (fingerprints - low risk)
- ⚠️ `config` (SSH client config - may contain sensitive paths)

**Security Implications:**
- Private key can be stolen by:
  - Root user on remote host
  - Other users with misconfigured permissions
  - Compromised remote host
  - Backup systems that capture `~/devcontainers/ssh_keys`

#### Step 1.4: Copy Public Key to Remote Cache
```bash
scp ~/.ssh/id_ed25519.pub rmanaloto@c24s1.ch2:~/devcontainers/ssh_keys/id_ed25519.pub
```
**Purpose:** Separate location for authorized_keys injection

#### Step 1.5: Trigger Remote Build
```bash
ssh rmanaloto@c24s1.ch2 \
  REPO_PATH="~/dev/github/SlotMap" \
  SANDBOX_PATH="~/dev/devcontainers/SlotMap" \
  KEY_CACHE="~/devcontainers/ssh_keys" \
  BRANCH="$CURRENT_BRANCH" \
  bash <<'EOF'
set -euo pipefail
cd "$REPO_PATH"
git fetch origin
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"
./scripts/run_local_devcontainer.sh
EOF
```

---

### Phase 2: Remote Build & Deploy (c24s1.ch2)

**Script:** `scripts/run_local_devcontainer.sh`
**Execution Context:** Remote host (c24s1.ch2)

#### Step 2.1: Recreate Sandbox
```bash
# Remove old sandbox
rm -rf ~/dev/devcontainers/SlotMap

# Create fresh copy from canonical repo
rsync -a --delete ~/dev/github/SlotMap/ ~/dev/devcontainers/SlotMap/
```

**Purpose:** Ensure clean state, no stale files

**Directory Structure After This Step:**
```
/home/rmanaloto/
├── dev/
│   ├── github/
│   │   └── SlotMap/              # Canonical repo (git managed)
│   └── devcontainers/
│       ├── SlotMap/               # Sandbox (throwaway copy)
│       └── workspace/             # Bind mount source
└── devcontainers/
    └── ssh_keys/                  # Synced from Mac
        ├── id_ed25519 ⚠️
        └── id_ed25519.pub
```

#### Step 2.2: Stage SSH Keys
```bash
SSH_TARGET="~/dev/devcontainers/SlotMap/.devcontainer/ssh"
mkdir -p "$SSH_TARGET"

# Copy public keys only (⚠️ script actually copies all)
cp ~/devcontainers/ssh_keys/*.pub "$SSH_TARGET/"
```

**Expected:** Only `*.pub` files
**Actual:** Script copies ALL files if they exist

#### Step 2.3: Build Base Image (if missing)
```bash
docker buildx bake \
  -f .devcontainer/docker-bake.hcl \
  base \
  --set base.tags="dev-base:local" \
  --set '*.args.USERNAME'="rmanaloto" \
  --set '*.args.USER_UID'="$(id -u)" \
  --set '*.args.USER_GID'="$(id -g)"
```

**Build Stages:**
1. Ubuntu 24.04 base
2. Add apt repositories (LLVM, GCC, Kitware)
3. Install system packages
4. Create user with matching UID/GID

**Build Time:** ~15 minutes (cached after first run)

#### Step 2.4: Build Tool Stages (Parallel)
```bash
docker buildx bake \
  -f .devcontainer/docker-bake.hcl \
  tools \
  --set base.tags="dev-base:local" \
  --set '*.args.BASE_IMAGE'="dev-base:local"
```

**Parallel Stages (15 total):**
```
├── clang_p2996     (compile from source ~30 min)
├── node_mermaid    (install Node.js + mermaid-cli)
├── mold            (download binary)
├── gh_cli          (download binary)
├── ccache          (download binary)
├── sccache         (download binary)
├── ripgrep         (download binary)
├── cppcheck        (compile from source)
├── valgrind        (compile from source)
├── python_tools    (pip install packages)
├── pixi            (download binary)
├── iwyu            (compile from source)
├── mrdocs          (download binary)
├── jq              (download binary)
└── awscli          (pip install)
```

**Build Time:** ~45 minutes (first run), ~5 minutes (cached)
**Parallelism:** BuildKit builds all stages concurrently

#### Step 2.5: Merge Tool Stages
```bash
docker buildx bake \
  -f .devcontainer/docker-bake.hcl \
  tools_merge
```

**Purpose:** Copy all tools into a single layer

#### Step 2.6: Build Final Devcontainer Image
```bash
docker buildx bake \
  -f .devcontainer/docker-bake.hcl \
  devcontainer \
  --set devcontainer.tags="devcontainer:local"
```

**Final Image Contents:**
- Base OS (Ubuntu 24.04)
- User `rmanaloto` (UID/GID match host)
- All 15 tool stages
- Devcontainer Feature: sshd (port 2222)
- vcpkg installation
- Workspace directory

#### Step 2.7: Run Container
```bash
devcontainer up \
  --workspace-folder ~/dev/devcontainers/SlotMap \
  --remove-existing-container \
  --build-no-cache
```

**What This Does:**
1. Reads `.devcontainer/devcontainer.json`
2. Creates container from `devcontainer:local` image
3. Applies bind mounts:
   - `~/dev/devcontainers/workspace` → `/home/rmanaloto/workspace`
   - `~/devcontainers/ssh_keys` → `/home/rmanaloto/.ssh` ⚠️
4. Exposes port `9222:2222` (host:container)
5. Runs `postCreateCommand`: `.devcontainer/scripts/post_create.sh`

**Post-Create Script Actions:**
```bash
# Inject public keys into authorized_keys
cat .devcontainer/ssh/*.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Start sshd (Feature already handles this)
# Configure git user
git config --global user.name "..."
git config --global user.email "..."
```

---

### Phase 3: SSH Connectivity Test (Mac)

**Script:** `scripts/test_devcontainer_ssh.sh`
**Execution Context:** Developer's Mac

#### Step 3.1: Clear Known Host Entry
```bash
ssh-keygen -R "[c24s1.ch2]:9222" -f ~/.ssh/known_hosts
```
**Purpose:** Avoid host key mismatch (container recreated)

#### Step 3.2: Test SSH Connection
```bash
ssh -vvv \
  -i ~/.ssh/id_ed25519 \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=no \
  -p 9222 \
  rmanaloto@c24s1.ch2 \
  "echo SSH_OK"
```

**Authentication Flow:**
```
Mac → c24s1.ch2:9222 → Container:2222 (sshd)
  1. TCP connection established
  2. sshd presents host key (container's key)
  3. Mac sends public key fingerprint
  4. sshd checks ~/.ssh/authorized_keys
  5. sshd sends challenge
  6. Mac signs challenge with private key
  7. sshd verifies signature
  8. Connection authenticated
```

#### Step 3.3: Validate Container Environment
```bash
ssh -i ~/.ssh/id_ed25519 -p 9222 rmanaloto@c24s1.ch2 <<'EOF'
# Check user
whoami  # Expected: rmanaloto
id      # Expected: uid/gid matching remote host

# Check workspace
test -w $HOME/workspace && echo "writable"

# Check sudo
sudo -n true  # Expected: success (passwordless)

# Check tools
clang++-21 --version
ninja --version
cmake --version
vcpkg --version
mrdocs --version

# Check GitHub SSH ⚠️ Uses private key from bind mount
ssh -i $HOME/.ssh/id_ed25519 -T git@github.com
EOF
```

---

## Protocol Deep Dive

### SSH Protocol Stack

#### Mac → Remote Host (Phase 1)

**Connection 1: Git Push**
```
Protocol: SSH (OpenSSH)
Port: 22 (standard)
Authentication: Public key (id_ed25519)
Data Transfer: Git protocol over SSH

Flow:
  Mac SSH Client → c24s1.ch2 SSH Server
    ├─ Authenticate with ~/.ssh/id_ed25519
    ├─ Execute: git-receive-pack
    └─ Transfer: Git objects

Used By: git push origin <branch>
```

**Connection 2: rsync (Key Sync)**
```
Protocol: rsync over SSH
Port: 22
Authentication: Public key (id_ed25519)
Data Transfer: rsync protocol in SSH tunnel

Flow:
  Mac rsync → Mac SSH Client → c24s1.ch2 SSH Server → c24s1.ch2 rsync
    ├─ Authenticate with ~/.ssh/id_ed25519
    ├─ Execute: mkdir -p ... && rsync (remote command)
    ├─ Transfer: File data (delta algorithm)
    └─ Set permissions: chmod F600,D700

Files Transferred:
  ~/.ssh/ → ~/devcontainers/ssh_keys/
    ├─ id_ed25519 ⚠️ (private key, ~400 bytes)
    ├─ id_ed25519.pub (public key, ~100 bytes)
    ├─ known_hosts (host fingerprints, variable)
    └─ config (SSH client config, variable)
```

**Connection 3: Remote Script Execution**
```
Protocol: SSH (bash heredoc)
Port: 22
Authentication: Public key (id_ed25519)
Data Transfer: stdin → remote bash

Flow:
  Mac SSH Client → c24s1.ch2 SSH Server
    ├─ Authenticate with ~/.ssh/id_ed25519
    ├─ Execute: bash (with stdin from heredoc)
    └─ Environment variables passed via SSH

Script Actions:
  cd $REPO_PATH
  git fetch origin
  git checkout $BRANCH
  git pull --ff-only origin $BRANCH
  ./scripts/run_local_devcontainer.sh
```

#### Mac → Container (Phase 3)

**Connection: Development SSH**
```
Protocol: SSH (OpenSSH)
Port: 9222 (host) → 2222 (container)
Authentication: Public key (id_ed25519)
Tunnel: Mac → c24s1.ch2:22 → c24s1.ch2:9222 → container:2222

Flow:
  Mac SSH Client → c24s1.ch2:9222 (Docker port mapping) → Container:2222 (sshd)
    ├─ TCP: Mac connects to c24s1.ch2:9222
    ├─ Docker: Forwards to container port 2222
    ├─ sshd: Receives connection in container
    ├─ Auth: Container checks ~/.ssh/authorized_keys
    │         (contains Mac's public key)
    └─ Shell: Login shell for user rmanaloto

Used By:
  - Manual SSH: ssh -p 9222 rmanaloto@c24s1.ch2
  - CLion Remote Development
  - VS Code Remote SSH
```

### Docker Protocol Stack

#### Docker Daemon Communication (Remote Host)

**Local Socket Communication**
```
Protocol: Docker API over Unix socket
Socket: /var/run/docker.sock
Authentication: Unix file permissions (docker group)

Flow:
  devcontainer CLI → /var/run/docker.sock → Docker Daemon
    ├─ HTTP API calls (REST)
    ├─ Container lifecycle (create, start, stop)
    ├─ Image operations (build, pull, tag)
    └─ Network/volume management

Commands:
  docker buildx bake ...
  devcontainer up ...
  docker ps ...
  docker exec ...
```

**BuildKit Communication**
```
Protocol: gRPC over Unix socket
Socket: /var/run/buildkit/buildkitd.sock
Authentication: Unix file permissions

Flow:
  docker buildx bake → BuildKit → Docker Daemon
    ├─ Parse HCL build definition
    ├─ Build stages in parallel (up to CPU cores)
    ├─ Cache layer metadata
    └─ Push images to local Docker daemon

Parallelism:
  - 15 tool stages build concurrently
  - Limited by CPU cores and memory
  - Cache hits skip builds entirely
```

### Docker Networking

#### Port Mapping (Container → Host)

**Configuration (devcontainer.json:9-10)**
```json
"runArgs": ["-p", "9222:2222"]
```

**Mapping:**
```
External: c24s1.ch2:9222 (exposed to network)
    ↓
Docker Bridge: docker0 (172.17.0.1)
    ↓
Container: eth0:2222 (172.17.0.x)
    ↓
Process: sshd (listening on 0.0.0.0:2222)
```

**Routing:**
```
Mac (any port) → Internet → c24s1.ch2:9222
                                ↓
                        iptables DNAT rule
                                ↓
                        172.17.0.x:2222
```

**Security:**
- Port 9222 is exposed to **all network interfaces** (0.0.0.0)
- No firewall rules in current config
- Anyone who can reach c24s1.ch2:9222 can attempt SSH connection
- Protected only by SSH authentication (public key)

### File System Protocols

#### Bind Mounts

**Mount 1: Workspace**
```
Type: bind
Source: /home/rmanaloto/dev/devcontainers/workspace (host)
Target: /home/rmanaloto/workspace (container)
Consistency: cached (optimized for read-heavy workloads)

Behavior:
  - Changes in container are immediately visible on host
  - Changes on host are eventually visible in container (cached)
  - File permissions preserved (UID/GID matching required)
```

**Mount 2: SSH Keys ⚠️**
```
Type: bind
Source: /home/rmanaloto/devcontainers/ssh_keys (host)
Target: /home/rmanaloto/.ssh (container)
Consistency: cached

Contents:
  ├─ id_ed25519 ⚠️ (private key, 600 permissions)
  ├─ id_ed25519.pub (public key, 644 permissions)
  ├─ authorized_keys (generated by post-create script)
  ├─ known_hosts (synced from Mac)
  └─ config (synced from Mac)

Risk: Private key accessible to any process in container
```

**Mount 3: vcpkg Downloads (Volume)**
```
Type: volume
Name: slotmap-vcpkg
Source: Docker volume (managed storage)
Target: /opt/vcpkg/downloads (container)

Purpose: Persist vcpkg package downloads across container recreations
Size: ~2-5 GB (grows over time)
```

---

## Security Architecture

### Authentication Chains

#### Chain 1: Mac → Remote Host
```
┌─────────┐
│  Mac    │
│         │
│ Private │ Signs challenge
│  Key    │
└────┬────┘
     │ SSH connection (port 22)
     │ Authentication: Public Key
     ▼
┌─────────┐
│ c24s1   │
│         │
│ Public  │ Verifies signature
│  Key    │ (~/.ssh/authorized_keys)
└─────────┘

Trust Anchor: Mac's private key (~/.ssh/id_ed25519)
Risk: Private key compromise = full remote access
```

#### Chain 2: Mac → Container (via Remote Host)
```
┌─────────┐
│  Mac    │
│         │
│ Private │ Signs challenge
│  Key    │
└────┬────┘
     │ SSH connection (port 9222 → 2222)
     │ Tunneled through: c24s1.ch2
     ▼
┌─────────┐
│Container│
│         │
│ Public  │ Verifies signature
│  Key    │ (~/.ssh/authorized_keys)
│         │ (Injected from .devcontainer/ssh/*.pub)
└─────────┘

Trust Anchor: Mac's private key (same as Chain 1)
Risk: Same private key used for two different authentication targets
```

#### Chain 3: Container → GitHub (Current Implementation ⚠️)
```
┌──────────┐
│Container │
│          │
│ Private  │ ⚠️ Uses bind-mounted key
│  Key     │    /home/rmanaloto/.ssh/id_ed25519
│          │ Signs challenge
└────┬─────┘
     │ SSH connection (port 22)
     │ Outbound from container
     ▼
┌──────────┐
│ GitHub   │
│          │
│ Public   │ Verifies signature
│  Key     │ (uploaded to GitHub account)
└──────────┘

Trust Anchor: Same private key as Chains 1 & 2
Risk: Private key exposed on remote filesystem
      Single key used for three different purposes
```

### Current Security Issues

#### Issue 1: Private Key Exposure (CRITICAL)
**Location:** `scripts/deploy_remote_devcontainer.sh:121`

**Problem:**
```bash
rsync ... ~/.ssh/ rmanaloto@c24s1.ch2:~/devcontainers/ssh_keys/
```

**Impact:**
- Private key stored on remote filesystem: `~/devcontainers/ssh_keys/id_ed25519`
- Private key bind-mounted into container: `/home/rmanaloto/.ssh/id_ed25519`
- Accessible by:
  - Root user on remote host
  - Any process running as `rmanaloto` on remote host
  - Any process inside container
  - Backup systems capturing `/home/rmanaloto`

**Attack Scenarios:**
1. **Compromised Container:** Malicious code in build/test scripts can exfiltrate key
2. **Shared Host:** Other developers with sudo can access keys
3. **Backup Exposure:** Keys captured in unencrypted backups
4. **Forensic Residue:** Keys remain in filesystem/swap after deletion

**Mitigation:** See `docs/CRITICAL_FINDINGS.md` Section 1

#### Issue 2: Single Key for Multiple Purposes (HIGH)
**Problem:** Same `id_ed25519` key used for:
1. Mac → Remote Host authentication
2. Mac → Container authentication
3. Container → GitHub authentication

**Impact:**
- Key compromise grants access to all three systems
- Cannot revoke access to one without affecting others
- Audit trails conflate different users/purposes

**Best Practice:** Use separate keys:
- `id_ed25519_remote` for remote host access
- `id_ed25519_container` for container access (or agent forwarding)
- Deploy key for GitHub (read-only if possible)

#### Issue 3: Overly Permissive Port Exposure (MEDIUM)
**Location:** `devcontainer.json:9-10`

**Problem:**
```json
"runArgs": ["-p", "9222:2222"]
```

**Impact:**
- Port 9222 exposed on **all interfaces** (0.0.0.0)
- Anyone on network can connect to container SSH
- No IP filtering or VPN requirement

**Better:** Bind to localhost only:
```json
"runArgs": ["-p", "127.0.0.1:9222:2222"]
```
Then use SSH tunnel from Mac:
```bash
ssh -L 9222:localhost:9222 rmanaloto@c24s1.ch2
ssh -p 9222 rmanaloto@localhost  # Connects to container
```

#### Issue 4: Test Script Uses Private Key (MEDIUM)
**Location:** `scripts/test_devcontainer_ssh.sh:112`

**Problem:**
```bash
ssh -i "$HOME/.ssh/id_ed25519" -T git@github.com
```

**Impact:**
- Test requires private key to be present in container
- Perpetuates the bind-mount security issue
- Fails if agent forwarding is used

**Mitigation:** Use agent forwarding or `gh` CLI:
```bash
# Option 1: Agent forwarding
ssh -T git@github.com  # No -i flag

# Option 2: gh CLI (uses credential store)
gh auth status
```

---

## Performance Characteristics

### Build Times (Remote Host: example c24s1.ch2)

**First Build (Cold Cache):**
```
Base image build:          ~15 minutes
Tool stages (parallel):    ~45 minutes
Tools merge:               ~2 minutes
Final devcontainer:        ~3 minutes
─────────────────────────────────────
Total:                     ~65 minutes
```

**Incremental Build (Warm Cache):**
```
Base image (cached):       ~0 seconds
Tool stages (cached):      ~0 seconds
Tools merge (cached):      ~0 seconds
Final devcontainer:        ~3 minutes (user args changed)
─────────────────────────────────────
Total:                     ~3 minutes
```

**Factors Affecting Build Time:**
- **Parallel stages:** BuildKit can build all 15 tool stages concurrently
- **CPU cores:** More cores = more parallel builds
- **Network:** Downloading tools (mold, gh, etc.) limited by bandwidth
- **Disk I/O:** vcpkg downloads and cache layers

### Container Startup Time

**devcontainer up:**
```
Container creation:        ~2 seconds
Post-create script:        ~5 seconds
SSH service start:         ~1 second
─────────────────────────────────────
Total:                     ~8 seconds
```

### File Sync Performance

**rsync (Mac → Remote Host):**
```
First sync (~/.ssh):       ~1 second (4 files, ~5 KB)
Subsequent syncs:          ~0.5 seconds (delta check)
```

**Impact of Bind Mounts:**
```
Write in container → Visible on host:  ~10ms (immediate)
Write on host → Visible in container:  ~100ms (cached mode)
```

---

## Failure Modes & Recovery

### Failure Mode 1: Build Failure During Tool Stage

**Symptoms:**
```
ERROR: failed to solve: process "/bin/sh -c ..." did not complete successfully
```

**Cause:** Network timeout, compilation error, missing dependency

**Recovery:**
1. Check which stage failed: `docker buildx bake --progress=plain 2>&1 | grep ERROR`
2. Rebuild single stage: `docker buildx bake <stage_name>`
3. If persistent, inspect logs: `docker logs <container_id>`

### Failure Mode 2: SSH Connection Refused

**Symptoms:**
```
ssh: connect to host c24s1.ch2 port 9222: Connection refused
```

**Diagnosis:**
```bash
# On remote host:
docker ps  # Check container running
docker logs <container_id> | grep sshd  # Check SSH service
docker exec <container_id> ps aux | grep sshd  # Check process
```

**Recovery:**
```bash
# Restart container:
docker restart <container_id>

# Or rebuild:
cd ~/dev/devcontainers/SlotMap
devcontainer up --remove-existing-container
```

### Failure Mode 3: Permission Denied (Workspace)

**Symptoms:**
```
touch: cannot touch 'workspace/test': Permission denied
```

**Cause:** UID/GID mismatch between host and container

**Diagnosis:**
```bash
# On remote host:
stat ~/dev/devcontainers/workspace  # Note UID/GID

# In container:
id  # Compare with host
```

**Recovery:**
```bash
# Rebuild with correct UID/GID:
CONTAINER_UID=$(id -u) \
CONTAINER_GID=$(id -g) \
./scripts/run_local_devcontainer.sh
```

### Failure Mode 4: vcpkg Download Failure

**Symptoms:**
```
CMake Error: vcpkg install failed
error: failed to download <package>
```

**Cause:** Network issue, vcpkg registry down

**Recovery:**
```bash
# In container:
rm -rf /opt/vcpkg/downloads/*  # Clear cache
vcpkg install --recurse  # Retry
```

---

## Operational Procedures

### Daily Development Workflow

**Start Development Session:**
```bash
# 1. Ensure branch is up to date
cd ~/dev/github/SlotMap
git pull

# 2. Deploy to remote (if changes made)
./scripts/deploy_remote_devcontainer.sh

# 3. Connect via SSH
ssh -i ~/.ssh/id_ed25519 -p 9222 rmanaloto@c24s1.ch2

# 4. Or connect via IDE
# CLion: Tools → Deployment → Browse Remote Host
# VS Code: Remote-SSH: Connect to Host
```

**Make Changes:**
```bash
# In container:
cd ~/workspace
# Edit files, run builds, tests
cmake --preset clang-debug
cmake --build --preset clang-debug
ctest --preset clang-debug
```

**Commit Changes:**
```bash
# In container (⚠️ uses bind-mounted private key):
git add .
git commit -m "..."
git push origin <branch>
```

**End Session:**
```bash
# Just disconnect SSH; container keeps running
exit
```

### Maintenance Procedures

**Update Tools:**
```bash
# 1. Update docker-bake.hcl versions:
vim .devcontainer/docker-bake.hcl
# Change LLVM_VERSION, NODE_VERSION, etc.

# 2. Force rebuild:
./scripts/deploy_remote_devcontainer.sh

# 3. Verify:
ssh -p 9222 rmanaloto@c24s1.ch2 'clang++-21 --version'
```

**Clean Up Old Images:**
```bash
# On remote host:
docker image prune -a  # Remove unused images
docker volume prune     # Remove unused volumes
```

**Rotate SSH Keys:**
```bash
# 1. Generate new key on Mac:
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new

# 2. Update deploy script to use new key:
./scripts/deploy_remote_devcontainer.sh --ssh-key ~/.ssh/id_ed25519_new.pub

# 3. Test connection:
ssh -i ~/.ssh/id_ed25519_new -p 9222 rmanaloto@c24s1.ch2

# 4. Remove old key from GitHub, remote host
```

---

## Compliance & Audit

### Security Audit Checklist

**File Permissions:**
```bash
# On remote host:
ls -la ~/devcontainers/ssh_keys/
# Expected: 600 for private keys, 644 for public keys

# In container:
ls -la ~/.ssh/
# Expected: 600 for private keys, 644 for public/authorized_keys
```

**Key Usage Audit:**
```bash
# Check SSH auth logs:
sudo journalctl -u ssh | grep "Accepted publickey"

# Check GitHub audit log:
# https://github.com/settings/security-log
# Filter: Action = "auth" Source = "git"
```

**Container Security Scan:**
```bash
# Scan image for vulnerabilities:
docker scout cves devcontainer:local

# Check running container:
docker scout cves <container_id>
```

### Backup & Disaster Recovery

**Critical Files to Backup:**
```
Mac:
  ~/.ssh/id_ed25519 (encrypted backup only)
  ~/.ssh/known_hosts
  ~/dev/github/SlotMap (git handles backup)

Remote Host:
  ~/dev/github/SlotMap (git handles backup)
  ~/dev/devcontainers/workspace (important: work in progress)
  Docker volume: slotmap-vcpkg (optimization only, can rebuild)
```

**Recovery Procedure:**
```bash
# 1. Restore git repo:
git clone <repo> ~/dev/github/SlotMap

# 2. Rebuild container:
cd ~/dev/github/SlotMap
./scripts/deploy_remote_devcontainer.sh

# 3. Restore WIP files (if backed up):
rsync -av <backup>/workspace/ ~/dev/devcontainers/workspace/
```

---

## Known Limitations

1. **Single Remote Host:** No multi-host or high-availability setup
2. **No Container Persistence:** Container is removed and recreated on each deploy
3. **No Automated Updates:** Tool versions must be manually updated in HCL file
4. **No Monitoring:** No metrics collection or alerting for container health
5. **No Access Control:** Any user on remote host can potentially access keys
6. **Build Time:** Initial build takes ~65 minutes
7. **Network Dependency:** Cannot work offline (requires GitHub, vcpkg registries)

---

## Comparison: Current vs. Proposed Architecture

*See `docs/REFACTORING_ROADMAP.md` for detailed comparison and migration plan.*
