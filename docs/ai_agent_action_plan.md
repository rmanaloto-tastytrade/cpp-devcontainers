# AI Agent Action Plan: Devcontainer Refactoring

## Context for AI Agents

This repository contains a C++ project (`SlotMap`) with a custom devcontainer setup. The current setup uses complex shell scripts and `docker-bake` to orchestrate remote builds via Docker SSH contexts.

**Goal:** Refactor the setup to use native `devcontainer` CLI features, improve security, and simplify the architecture.

**Constraints:**

* **OS:** macOS (Host), Ubuntu (Container).
* **Tools:** `devcontainer` CLI, Docker, SSH.
* **Priority:** Security fixes first, then architectural simplification.
* **Parallelism:** Agents may be working on different tasks simultaneously. Check file locks or git status before editing.

---

## Task 1: Security Hardening (Critical)

**Objective:** Stop syncing private SSH keys to the remote host.

### Instructions

1. **Analyze:** Read `scripts/deploy_remote_devcontainer.sh`.
2. **Modify:** Locate the `rsync` command (approx line 121).
3. **Action:** Change the source/filter to ONLY include `*.pub` files or explicitly exclude private keys.
    * *Hint:* Use `--include='*.pub' --exclude='*'`.
4. **Update Test Script:** Modify `scripts/test_devcontainer_ssh.sh` to stop using `-i $HOME/.ssh/id_ed25519` for the internal GitHub check. It should rely on the forwarded agent or `gh` CLI.
5. **Verify:** Run a dry-run rsync command to ensure only public keys are selected.

---

## Task 2: Devcontainer Configuration Refactor

**Objective:** Move build logic from `docker-bake.hcl` to `devcontainer.json`.

### Instructions

1. **Analyze:** Read `.devcontainer/devcontainer.json` and `.devcontainer/docker-bake.hcl`.
2. **Modify:** Update `devcontainer.json` to use the `build` property.

    ```json
    "build": {
        "dockerfile": "Dockerfile",
        "args": {
            "UBUNTU_VERSION": "24.04",
            // ... copy other args from docker-bake.hcl
        }
    }
    ```

3. **Cleanup:** Remove the `image` property from `devcontainer.json`.
4. **Note:** Do not delete `docker-bake.hcl` yet until the new build is verified.

---

## Task 3: Feature Adoption

**Objective:** Replace manual Dockerfile installations with Devcontainer Features.

### Instructions

1. **Analyze:** Read `.devcontainer/Dockerfile`.
2. **Identify:** Sections installing `sshd`, `node`, `gh`, `awscli`.
3. **Modify:** Add corresponding features to `.devcontainer/devcontainer.json`.
    * `ghcr.io/devcontainers/features/sshd:1`
    * `ghcr.io/devcontainers/features/node:1`
    * `ghcr.io/devcontainers/features/github-cli:1`
    * `ghcr.io/devcontainers/features/aws-cli:1`
4. **Action:** Delete the corresponding `RUN` instructions and `ARG`s from the `Dockerfile`.

---

## Task 4: Workflow Simplification

**Objective:** Deprecate custom scripts in favor of `devcontainer` CLI.

### Instructions

1. **Create:** A new documentation file `docs/new_workflow.md` describing how to run the container using the CLI:

    ```bash
    devcontainer up --workspace-folder . --docker-host "ssh://user@host"
    ```

2. **Deprecate:** Add a warning to the top of `scripts/deploy_remote_devcontainer.sh` and `scripts/run_local_devcontainer.sh` stating they are deprecated.

---

## Verification Protocol

For any changes made:

1. **Lint:** Ensure JSON files are valid.
2. **Build:** Run `devcontainer build --workspace-folder .` locally to verify configuration syntax.
3. **Test:** If possible, run a test build against a remote context (if credentials allow).

## Shared Knowledge

* **Remote Host:** `c24s1.ch2` (example).
* **Remote User:** `rmanaloto` (or current user).
* **SSH Port:** 9222 (Container), 22 (Host).
