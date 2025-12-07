# AI Agent Action Plan: Devcontainer Refactoring

## Context for AI Agents

This repository contains a C++ project (`SlotMap`) with a custom devcontainer setup. The current setup uses complex shell scripts and `docker-bake` to orchestrate remote builds via Docker SSH contexts.

**Goal:** Refactor the setup to use native `devcontainer` CLI features, improve security, and simplify the architecture.

## Top Priority: Self-Hosted Devcontainer Builds via GHA

**Objective:** Make the self-hosted GitHub Actions workflow the authoritative path to build and publish the devcontainer images (all permutations) using the project’s automation. See `docs/self_hosted_devcontainer_gha_plan.md` for the current-state analysis and detailed plan. Complete this before the tasks below.

**AI agents to use for reviews:** codex, claude, gemini, cursor-agent, copilot, docker ai (Ask Gordon).

**Security note:** runner/secret hygiene and rollback/retention scripts are documented in `docs/runner_security.md`.

**Constraints:**

* **OS:** macOS (Host), Ubuntu (Container).
* **Tools:** `devcontainer` CLI, Docker, SSH.
* **Priority:** Security fixes first, then architectural simplification.
* **Parallelism:** Agents may be working on different tasks simultaneously. Check file locks or git status before editing.

---

## Task 0: Parameterize Host/User/Port (Top Priority)

**Objective:** Remove hardcoded references to a specific Mac user, host, or SSH port across devcontainer configs and scripts; make them configurable via script args/env.

### Instructions
1. **Identify hardcoded values**: search for `c24s1`, `9222`, `ray.manaloto`, and `ray.manaloto@tastytrade.com` in `.devcontainer/**` and `scripts/*.sh`.
2. **Scripts**: ensure `deploy_remote_devcontainer.sh`, `run_local_devcontainer.sh`, and `test_devcontainer_ssh.sh` accept `--host/--port/--user` (with neutral defaults or required params). Remove baked-in defaults to specific hosts/ports/users.
3. **devcontainer.json**: parameterize SSH port in `runArgs` and `sshd` feature options using `${localEnv:DEVCONTAINER_SSH_PORT:-9222}` (or equivalent). Keep user configurable via `DEVCONTAINER_USER`.
4. **Docs**: update references to example hosts/ports to note they are configurable; avoid implying fixed hosts. Leave examples as placeholders.
5. **Validation**: rerun `./scripts/pre_commit.sh` and redeploy to confirm the parameterized setup still works with supplied args/env.
6. **Guardrail**: `scripts/check_hardcoded_refs.sh` runs in `pre_commit.sh` to fail if personal host/user strings reappear in code; update its pattern list if new personal strings need blocking.

**Sources:** Devcontainer variable substitution `${localEnv:VAR}` (Dev Containers spec), shell script arg patterns.

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

### Task 1.1: Configure Remote-Resident Agent (Optional)

If the "Remote-Resident" workflow is selected (per user request):

1. **Modify:** Update `devcontainer.json` to bind-mount the SSH agent socket.

    ```json
    "mounts": ["source=${localEnv:SSH_AUTH_SOCK},target=/tmp/ssh-agent.socket,type=bind"],
    "containerEnv": { "SSH_AUTH_SOCK": "/tmp/ssh-agent.socket" }
    ```

2. **Prerequisite:** Ensure the remote host has `SSH_AUTH_SOCK` set in the environment where `devcontainer` CLI runs.

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

1. **Analyze:**### Task 6: Adopt Devcontainer Features & Clean Dockerfile
1. **Modify:** Update `devcontainer.json` to include features:

    ```json
    "features": {
        "ghcr.io/devcontainers/features/sshd:1": { "version": "latest" },
        "ghcr.io/devcontainers/features/common-utils:2": { "username": "slotmap", "userUid": 1000, "userGid": 1000 },
        "ghcr.io/devcontainers/features/node:1": { "version": "20" },
        "ghcr.io/devcontainers/features/github-cli:1": {},
        "ghcr.io/devcontainers/features/aws-cli:1": {},
        "ghcr.io/devcontainers/features/python:1": {}
    }
    ```

2. **Refactor Dockerfile:**
    * **Remove:** `ARG USERNAME`, `useradd`, `groupadd`, `sudo` setup (handled by `common-utils`).
    * **Remove:** Manual `node`, `gh`, `awscli`, `python` installation stages.
    * **Retain:** `clang-p2996`, `mrdocs`, `iwyu`, `vcpkg` setup.
3. **Verify:** Rebuild container (`devcontainer build`) and check `node --version`, `gh --version`, etc.json`.
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
