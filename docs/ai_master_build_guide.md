# AI Agent Master Build Guide

**Purpose:** This document is the single source of truth for an AI Agent to understand the `SergeyMakeev/SlotMap` devcontainer ecosystem and perform a fully automated reconstruction.

---

## 1. AI Context & Documentation Index

To gain full context on the architecture, "gotchas", and design decisions of this project, you **must** review the following optimized documents:

### Primary Architecture & Workflow

* **[Remote Devcontainer AI Guide (V2)](remote_devcontainer_ai_guide.md)**
  * *Read this first.* Explains the Mac Client -> Linux Host topology, SSH/Mutagen wiring, and critical failure modes (cold start perms, etc.).

### Project Context

* **[AI Agent Context](AI_AGENT_CONTEXT.md)**
  * Comprehensive inventory of the codebase, file locations, and build system facts.

### Session History & Fixes

* **[Walkthrough](walkthrough.md)**
  * Chronicle of the recent debugging session properly fixing SSH key propagation, dependency issues (`ty` 404), and `rsync` deployment logic.

---

## 2. Automated Reconstruction (Zero-Touch)

**Objective:** Delete all existing containers/artifacts and rebuild the entire matrix without manual intervention.

The project now includes a **single automation script** that satisfies the following requirements:

1. **Safety:** Cleans up *only* project-specific artifacts (`cpp-cpp-*` images, `cppdev-cache` volume).
2. **Coverage:** Iterates through all 6 configuration permutations (`gcc14/15` x `clang21/22/p2996`).
3. **Verification:** Validates SSH connectivity for each build.

### The Command

To execute the full lifecycle (Cleanup -> Build -> Verify):

```bash
# Execute on the local machine (Mac Client) form the project root
# This script manages the SSH connections to the remote host.
./scripts/verify_remote_devcontainer_matrix.sh
```

**Note:** Ensure the script is executable (`chmod +x scripts/verify_remote_devcontainer_matrix.sh`) before running.

### Expected Output

The script will produce a log directory `logs/matrix_YYYYMMDD_HHMMSS/` containing:

* `summary_report.md`: A table showing Pass/Fail status for each config.
* `<config>.log`: Detailed logs for each build permutation.

**Example Summary:**

| Config | Deploy | SSH check | Status |
|---|---|---|---|
| gcc14-clang21 | ✅ | ✅ | **PASS** |
| gcc14-clang22 | ✅ | ✅ | **PASS** |
| ... | ... | ... | ... |

### SSH into a Devcontainer (Mac → Remote → Container)

Use the helper script to connect without crafting SSH commands. Point it at the env file for the target permutation:

```bash
CONFIG_ENV_FILE=config/env/devcontainer.<host>.<perm>.env \
./scripts/ssh_devcontainer.sh
```

Examples:

```bash
# gcc14-clang21 on host c090s4
CONFIG_ENV_FILE=config/env/devcontainer.c090s4.gcc14-clang21.env ./scripts/ssh_devcontainer.sh

# gcc15-clangp2996 on host c090s4
CONFIG_ENV_FILE=config/env/devcontainer.c090s4.gcc15-clangp2996.env ./scripts/ssh_devcontainer.sh
```

The script reads the env file for host/user/port, sets up ProxyJump as needed, and connects directly into the container. No additional manual SSH steps are required.
