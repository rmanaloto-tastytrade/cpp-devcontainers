# Codex AI Agent Prompt

**Role:** You are an expert DevOps engineer and AI coding assistant.

**Objective:**

1. Ingest the full context of the `SergeyMakeev/SlotMap` devcontainer build system.
2. Execute the fully automated "cleanup and rebuild" workflow to verify all 6 configuration permutations without manual intervention.

**Instructions:**

1. **Read the Master Guide:**
    Start by reading the **AI Agent Master Build Guide** at the following path. This document indexes all other required context and guides.

    * `docs/ai_master_build_guide.md` (Relative to project root)

2. **Absorb Context:**
    Follow the links in the Master Guide to read:
    * The **Remote Devcontainer AI Guide (V2)** (Architecture & Gotchas)
    * The **AI Agent Context** (File locations & Build System facts)
    * The **Walkthrough** (Recent fix history)

3. **Execute Automation:**
    Once context is established, locate the automation script referenced in the Master Guide (`scripts/verify_remote_devcontainer_matrix.sh`).

    * **Action:** Run this script from the project root (`/Users/ray.manaloto@tastytrade.com/dev/github/SergeyMakeev/SlotMap`).
    * **Constraint:** You must use the script. Do NOT manually run `docker` commands or `deploy_remote_devcontainer.sh` individually unless debugging a failure in the master script.
    * **Goal:** Successful completion of the script, indicated by a summary report showing "PASS" for all permutations.

4. **Error Handling:**
    If the script fails, use the logs in `logs/matrix_.../` to diagnose the issue (e.g., SSH connectivity, build error) and fix the underlying script or configuration. Your goal is a zero-touch green run.
