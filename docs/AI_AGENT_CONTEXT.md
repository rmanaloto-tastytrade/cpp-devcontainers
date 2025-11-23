# AI Agent Context: SlotMap Devcontainer System

**Format:** Machine-readable facts for AI agent consumption
**Purpose:** Provide unambiguous context to prevent hallucination
**Last Updated:** 2025-01-22

---

## System Facts (Ground Truth)

### File Locations (Verified)

```yaml
local_machine:
  type: "macOS"
  working_directory: "/Users/ray.manaloto@tastytrade.com/dev/github/SergeyMakeev/SlotMap"
  private_key: "~/.ssh/id_ed25519"
  public_key: "~/.ssh/id_ed25519.pub"

remote_host:
  hostname: "c24s1.ch2"
  os: "Ubuntu 24.04"
  user: "rmanaloto"
  canonical_repo: "~/dev/github/SlotMap"
  sandbox_path: "~/dev/devcontainers/SlotMap"
  workspace_path: "~/dev/devcontainers/workspace"
  ssh_keys_cache: "~/devcontainers/ssh_keys"

container:
  image_name: "devcontainer:local"
  user: "rmanaloto"
  workspace: "/home/rmanaloto/workspace"
  ssh_port_container: 2222
  ssh_port_host: 9222
```

### File Paths (Exact)

```yaml
deployment_script: "scripts/deploy_remote_devcontainer.sh"
build_script: "scripts/run_local_devcontainer.sh"
test_script: "scripts/test_devcontainer_ssh.sh"
devcontainer_config: ".devcontainer/devcontainer.json"
docker_bake_file: ".devcontainer/docker-bake.hcl"
dockerfile: ".devcontainer/Dockerfile"
post_create_script: ".devcontainer/scripts/post_create.sh"
```

### Line Numbers (Exact - for editing)

```yaml
security_issue_rsync:
  file: "scripts/deploy_remote_devcontainer.sh"
  line_number: 121
  current_content: "rsync -e \"${RSYNC_SSH}\" -av --chmod=F600,D700 --rsync-path=\"mkdir -p ${REMOTE_SSH_SYNC_DIR} && rsync\" \"${SSH_SYNC_SOURCE}\" \"${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SSH_SYNC_DIR}/\""

security_issue_test_script:
  file: "scripts/test_devcontainer_ssh.sh"
  line_number: 112
  current_content: "ssh -F /dev/null -i \"$HOME/.ssh/id_ed25519\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10 -T git@github.com || true"

devcontainer_config_runArgs:
  file: ".devcontainer/devcontainer.json"
  line_number: 9
  current_content: "\"runArgs\": [\"-p\", \"9222:2222\"]"

devcontainer_config_sshd_feature:
  file: ".devcontainer/devcontainer.json"
  line_start: 27
  line_end: 34
  status: "ALREADY CONFIGURED"
  current_content: |
    "features": {
      "ghcr.io/devcontainers/features/sshd:1": {
        "version": "latest",
        "port": "9222",
        "publishPort": true,
        "gatewayPorts": "clientspecified",
        "options": "PermitRootLogin no"
      }
    }
```

### Build System Facts

```yaml
build_system:
  primary_tool: "docker buildx bake"
  config_file: ".devcontainer/docker-bake.hcl"
  parallel_stages: 15
  estimated_build_time_cold: "45-65 minutes"
  estimated_build_time_cached: "3-5 minutes"

tool_stages:
  - name: "clang_p2996"
    build_time: "30 minutes"
    type: "compile_from_source"
  - name: "node_mermaid"
    build_time: "5 minutes"
    type: "install"
  - name: "mold"
    build_time: "1 minute"
    type: "download_binary"
  - name: "gh_cli"
    build_time: "1 minute"
    type: "download_binary"
  - name: "ccache"
    build_time: "1 minute"
    type: "download_binary"
  - name: "sccache"
    build_time: "1 minute"
    type: "download_binary"
  - name: "ripgrep"
    build_time: "1 minute"
    type: "download_binary"
  - name: "cppcheck"
    build_time: "10 minutes"
    type: "compile_from_source"
  - name: "valgrind"
    build_time: "15 minutes"
    type: "compile_from_source"
  - name: "python_tools"
    build_time: "2 minutes"
    type: "pip_install"
  - name: "pixi"
    build_time: "1 minute"
    type: "download_binary"
  - name: "iwyu"
    build_time: "20 minutes"
    type: "compile_from_source"
  - name: "mrdocs"
    build_time: "1 minute"
    type: "download_binary"
  - name: "jq"
    build_time: "1 minute"
    type: "download_binary"
  - name: "awscli"
    build_time: "2 minutes"
    type: "pip_install"

docker_bake_value:
  benefit: "Builds all 15 stages in parallel"
  time_savings: "~45 minutes on first build"
  complexity: "Medium (1 HCL file, 190 lines)"
  alternative: "Sequential Dockerfile (simpler but 2x slower)"
  recommendation: "KEEP (justified complexity)"
```

### Security Issues (Confirmed)

```yaml
issue_1_private_key_exposure:
  severity: "CRITICAL"
  status: "CONFIRMED"
  file: "scripts/deploy_remote_devcontainer.sh"
  line: 121
  problem: "Syncs entire ~/.ssh/ including private keys"
  impact: "Private key accessible on remote filesystem and in container"
  fix_complexity: "LOW"
  breaking_change: "NO"

issue_2_single_key_multiple_purposes:
  severity: "HIGH"
  status: "CONFIRMED"
  problem: "Same key used for: Mac→Host, Mac→Container, Container→GitHub"
  impact: "Key compromise affects all three systems"
  fix_complexity: "MEDIUM"
  breaking_change: "YES (requires key rotation)"

issue_3_test_script_private_key:
  severity: "HIGH"
  status: "CONFIRMED"
  file: "scripts/test_devcontainer_ssh.sh"
  line: 112
  problem: "Test requires private key in container"
  impact: "Perpetuates security issue"
  fix_complexity: "LOW"
  breaking_change: "NO (works with agent or without)"

issue_4_port_exposure:
  severity: "MEDIUM"
  status: "CONFIRMED"
  file: ".devcontainer/devcontainer.json"
  line: 9
  problem: "Port 9222 exposed on all interfaces (0.0.0.0)"
  impact: "Anyone on network can attempt SSH connection"
  fix_complexity: "LOW"
  breaking_change: "YES (requires SSH tunnel from Mac)"
```

### Review Report Errors (Corrected)

```yaml
error_1_remote_resident_agent_config:
  severity: "CRITICAL_BUG"
  location: "docs/review_report.md lines 127-134"
  problem: "${localEnv:SSH_AUTH_SOCK} resolves on CLI machine, not Docker host"
  impact: "Configuration breaks if CLI runs on Mac (as proposed)"
  correct_solution: "Use hardcoded path: /home/rmanaloto/.ssh/agent.sock"
  prerequisites_missing: [
    "systemd service for ssh-agent",
    "stable socket path setup",
    "deploy key generation",
    "agent key loading"
  ]

error_2_docker_bake_removal:
  severity: "HIGH"
  location: "docs/review_report.md Section 3"
  recommendation: "Remove docker-bake"
  classification: "BAD ADVICE"
  reason: "Loses 45 min of parallel build optimization"
  impact: "Build time increases from 45min to 90min"
  correct_recommendation: "KEEP docker-bake"

error_3_workflow_simplification:
  severity: "MEDIUM"
  location: "docs/review_report.md Section 2"
  recommendation: "Use devcontainer up --docker-host ssh://user@host from Mac"
  problems: [
    "Breaks sandbox pattern",
    "Uploads 5GB build context over SSH",
    "Doesn't replicate rsync workflow",
    "Bind mounts become ambiguous"
  ]
  correct_recommendation: "Keep current workflow (with security fixes)"

error_4_duplicate_sshd_feature:
  severity: "MEDIUM"
  location: "docs/ai_agent_action_plan.md Task 3"
  recommendation: "Add sshd feature"
  problem: "sshd feature ALREADY configured (lines 27-34 of devcontainer.json)"
  impact: "AI would add duplicate, cause error"

error_5_feature_availability:
  severity: "MEDIUM"
  location: "docs/ai_agent_action_plan.md Task 3"
  recommendation: "Replace mold, mrdocs, iwyu, etc. with Features"
  problem: "These tools DON'T HAVE official Features"
  impact: "AI would delete manual installs, Features would fail to install, build breaks"
```

### Safe Changes (Non-Breaking)

```yaml
change_1_fix_rsync_filter:
  file: "scripts/deploy_remote_devcontainer.sh"
  line: 121
  type: "SAFE_MODIFICATION"
  breaking: false
  test_required: true
  old: "rsync ... ${SSH_SYNC_SOURCE} ..."
  new: "rsync ... --include='*.pub' --include='config' --include='known_hosts' --exclude='*' ${SSH_SYNC_SOURCE} ..."
  rollback: "revert commit, re-run deploy"

change_2_add_agent_support_to_test:
  file: "scripts/test_devcontainer_ssh.sh"
  line: 112
  type: "SAFE_ADDITION"
  breaking: false
  test_required: true
  old: "ssh -i \"$HOME/.ssh/id_ed25519\" -T git@github.com"
  new: |
    if ssh-add -l >/dev/null 2>&1; then
        ssh -T git@github.com 2>&1 || echo "Agent forwarding may not be configured"
    else
        echo "WARNING: No SSH agent available, skipping GitHub test"
    fi
  rollback: "revert commit, old method still works"

change_3_bind_port_to_localhost:
  file: ".devcontainer/devcontainer.json"
  line: 9
  type: "SAFE_MODIFICATION"
  breaking: true
  requires_tunnel: true
  old: "\"runArgs\": [\"-p\", \"9222:2222\"]"
  new: "\"runArgs\": [\"-p\", \"127.0.0.1:9222:2222\"]"
  additional_step: "ssh -L 9222:localhost:9222 rmanaloto@c24s1.ch2 -N -f"
  rollback: "revert commit, re-run deploy"
```

### Risky Changes (Require Testing)

```yaml
change_4_remote_resident_agent:
  type: "COMPLEX_ADDITION"
  breaking: false
  optional: true
  required_if: "Need GitHub access when Mac offline"
  prerequisites:
    - step: "Create systemd service on remote host"
      file: "~/.config/systemd/user/ssh-agent.service"
      content: |
        [Unit]
        Description=SSH Agent
        [Service]
        Type=simple
        ExecStart=/usr/bin/ssh-agent -D -a %h/.ssh/agent.sock
        [Install]
        WantedBy=default.target
    - step: "Enable service"
      command: "systemctl --user enable ssh-agent && systemctl --user start ssh-agent"
    - step: "Generate deploy key"
      command: "ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_deploy"
    - step: "Add key to agent"
      command: "ssh-add ~/.ssh/id_ed25519_deploy"
    - step: "Add public key to GitHub"
      file: "~/.ssh/id_ed25519_deploy.pub"
      upload_to: "https://github.com/settings/keys"
  configuration:
    - file: ".devcontainer/devcontainer.json"
      line: "after line 22"
      add: "\"source=/home/rmanaloto/.ssh/agent.sock,target=/tmp/ssh-agent.socket,type=bind\""
    - file: ".devcontainer/devcontainer.json"
      line: "in containerEnv section"
      add: "\"SSH_AUTH_SOCK\": \"/tmp/ssh-agent.socket\""
  test_steps:
    - "echo $SSH_AUTH_SOCK  # Should show: /tmp/ssh-agent.socket"
    - "ssh-add -l  # Should list deploy key"
    - "ssh -T git@github.com  # Should authenticate"
  rollback: "Remove mount and containerEnv entries, restart container"
```

---

## Decision Trees for AI Agents

### Should I Remove docker-bake?

```
START
  ↓
Is build time a concern?
  ├─ YES → Is 45 min savings valuable?
  │         ├─ YES → KEEP docker-bake
  │         └─ NO  → Consider removal (but test first)
  └─ NO  → Is simplicity more important than 45 min?
            ├─ YES → Test sequential build, measure impact
            └─ NO  → KEEP docker-bake

RECOMMENDATION: KEEP docker-bake (complexity justified by savings)
```

### Should I Use CLI from Mac or Remote Host?

```
START
  ↓
Do you need sandbox pattern?
  ├─ YES → Run CLI on remote host (current workflow)
  └─ NO  → ↓

Is build context > 1GB?
  ├─ YES → Run CLI on remote host (avoid network upload)
  └─ NO  → ↓

Do you have fast network (>100 Mbps)?
  ├─ YES → Could run CLI from Mac (test first)
  └─ NO  → Run CLI on remote host (current workflow)

RECOMMENDATION: Keep current workflow (CLI on remote host)
```

### Should I Implement Remote-Resident Agent?

```
START
  ↓
Do containers need GitHub access when Mac is offline?
  ├─ NO  → Use SSH Agent Forwarding (simpler)
  └─ YES → ↓

Are there long-running builds (>1 hour)?
  ├─ NO  → Use SSH Agent Forwarding (simpler)
  └─ YES → ↓

Can you manage separate deploy keys?
  ├─ YES → Implement Remote-Resident Agent
  └─ NO  → Use SSH Agent Forwarding (less maintenance)

RECOMMENDATION: Most cases use Agent Forwarding
```

### Can I Replace This Tool with a Feature?

```
START → Check tool name
  ↓
Is tool in this list: [sshd, node, gh, awscli, python, docker, git]?
  ├─ YES → Official Feature EXISTS
  │         ↓
  │         Check if already configured in devcontainer.json
  │         ├─ YES → DO NOT ADD (duplicate)
  │         └─ NO  → Can safely add Feature
  │
  └─ NO  → Is tool in this list: [mold, mrdocs, iwyu, clang_p2996, ccache, sccache, pixi, ripgrep, cppcheck, valgrind]?
            ├─ YES → NO Feature available (manual install required)
            └─ NO  → Search https://containers.dev/features (may exist)

RECOMMENDATION: Only replace gh and awscli with Features
```

---

## Validation Commands (Exact)

### Pre-Deployment Validation

```bash
# 1. Check git status
git status --porcelain
# Expected output: (empty)
# If not empty: STOP - commit or stash changes first

# 2. Verify SSH key exists
ls -la ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
# Expected: Both files exist with -rw------- and -rw-r--r-- permissions

# 3. Test remote host connectivity
ssh rmanaloto@c24s1.ch2 'echo REMOTE_OK'
# Expected output: REMOTE_OK
# If connection fails: STOP - check SSH config/keys
```

### Post-Deployment Validation

```bash
# 1. Container is running
ssh rmanaloto@c24s1.ch2 'docker ps --filter label=devcontainer.local_folder --format "{{.Status}}"'
# Expected: Up X minutes/hours

# 2. SSH to container works
ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9222 rmanaloto@c24s1.ch2 'echo CONTAINER_OK'
# Expected output: CONTAINER_OK

# 3. Tools are available
ssh -p 9222 rmanaloto@c24s1.ch2 'clang++-21 --version && cmake --version && ninja --version'
# Expected: Version output for all three tools

# 4. Workspace is writable
ssh -p 9222 rmanaloto@c24s1.ch2 'test -w ~/workspace && echo WORKSPACE_OK'
# Expected output: WORKSPACE_OK

# 5. GitHub SSH works (if agent configured)
ssh -p 9222 rmanaloto@c24s1.ch2 'ssh -T git@github.com 2>&1 | head -1'
# Expected: Hi <username>! You've successfully authenticated...
```

---

## Error Patterns & Solutions

### Error: "Host key verification failed"

```yaml
error_message: "Host key verification failed"
cause: "Container recreated, host key changed"
solution:
  command: "ssh-keygen -R \"[c24s1.ch2]:9222\" -f ~/.ssh/known_hosts"
  explanation: "Removes old container host key"
  alternative: "Use -o StrictHostKeyChecking=no (less secure)"
```

### Error: "Permission denied (publickey)"

```yaml
error_message: "Permission denied (publickey)"
cause: "Public key not in container's authorized_keys"
check_steps:
  - "ssh rmanaloto@c24s1.ch2 'cat ~/devcontainers/ssh_keys/*.pub'"
  - "ssh -p 9222 rmanaloto@c24s1.ch2 'cat ~/.ssh/authorized_keys'"
solution:
  command: "./scripts/deploy_remote_devcontainer.sh"
  explanation: "Re-runs deployment, re-injects keys"
```

### Error: "bind: address already in use"

```yaml
error_message: "bind: address already in use"
cause: "Port 9222 already bound by another container/process"
check_command: "ssh rmanaloto@c24s1.ch2 'docker ps' && netstat -an | grep 9222"
solution:
  - "Stop old container: docker stop <container_id>"
  - "Or: Change port in devcontainer.json and deploy script"
```

### Error: "failed to solve: process did not complete successfully"

```yaml
error_message: "failed to solve"
cause: "Docker build failure (compilation, network, dependency)"
debug_command: "docker buildx bake --progress=plain 2>&1 | tee build.log"
check_for:
  - "Network timeout: Check internet connection"
  - "Compilation error: Check if tool source repo changed"
  - "Missing dependency: Check if apt packages available"
solution: "Inspect build.log, fix specific stage, rebuild"
```

---

## Prohibited Actions for AI Agents

### DO NOT:

```yaml
prohibited_action_1:
  action: "Remove docker-bake.hcl"
  reason: "Loses 45 minutes of build time optimization"
  exception: "Only if explicitly requested and tested"

prohibited_action_2:
  action: "Add duplicate sshd feature"
  reason: "Already configured in devcontainer.json:27-34"
  check: "grep -A 10 '\"features\"' .devcontainer/devcontainer.json"

prohibited_action_3:
  action: "Use ${localEnv:SSH_AUTH_SOCK} for Remote-Resident Agent"
  reason: "Breaks when CLI runs from Mac (incorrect variable)"
  correct: "Use hardcoded path: /home/rmanaloto/.ssh/agent.sock"

prohibited_action_4:
  action: "Delete manual tool installations before verifying Features work"
  reason: "Many tools don't have Features (mold, mrdocs, iwyu, clang_p2996)"
  process: "Add Feature → Test build → Then remove manual install"

prohibited_action_5:
  action: "Change workflow to run devcontainer CLI from Mac"
  reason: "Breaks sandbox pattern, uploads 5GB over network, loses performance"
  exception: "Only if sandbox pattern is not needed AND network is fast"

prohibited_action_6:
  action: "Run git commands that modify canonical repo"
  reason: "Canonical repo should only be modified via git pull from GitHub"
  correct: "Work in container's workspace (bind-mounted)"

prohibited_action_7:
  action: "Mark tasks complete without validation"
  reason: "Changes may break system silently"
  required: "Run validation commands after each change"
```

---

## Task Success Criteria

### Task: Fix rsync Security Issue

```yaml
definition_of_done:
  - file_modified: "scripts/deploy_remote_devcontainer.sh:121"
  - rsync_includes: ["*.pub", "config", "known_hosts"]
  - rsync_excludes: ["*"]
  - dry_run_test: "rsync -avn --include='*.pub' --exclude='*' ~/.ssh/ /tmp/test/"
  - actual_deploy: "./scripts/deploy_remote_devcontainer.sh"
  - validation: "ssh rmanaloto@c24s1.ch2 'ls -la ~/devcontainers/ssh_keys/'"
  - expected_files: ["id_ed25519.pub", "config", "known_hosts"]
  - prohibited_files: ["id_ed25519", "id_rsa", "id_ecdsa"]
  - connection_still_works: "ssh -p 9222 rmanaloto@c24s1.ch2 'echo OK'"
```

### Task: Add SSH Agent Forwarding Support

```yaml
definition_of_done:
  - file_modified: "scripts/test_devcontainer_ssh.sh:112"
  - agent_check_added: "ssh-add -l >/dev/null 2>&1"
  - fallback_message: "Warns if agent not available"
  - old_method_still_works: "Backward compatible (doesn't break without agent)"
  - test_with_agent:
      - "eval \"$(ssh-agent -s)\""
      - "ssh-add ~/.ssh/id_ed25519"
      - "ssh -A -p 9222 rmanaloto@c24s1.ch2 'ssh -T git@github.com'"
  - test_without_agent:
      - "Prints warning message"
      - "Skips GitHub test gracefully"
```

### Task: Implement Remote-Resident Agent

```yaml
definition_of_done:
  - systemd_service_created: "~/.config/systemd/user/ssh-agent.service"
  - service_enabled: "systemctl --user is-enabled ssh-agent"
  - service_running: "systemctl --user is-active ssh-agent"
  - socket_exists: "ls -la ~/.ssh/agent.sock"
  - deploy_key_generated: "ls -la ~/.ssh/id_ed25519_deploy{,.pub}"
  - key_in_agent: "SSH_AUTH_SOCK=~/.ssh/agent.sock ssh-add -l | grep id_ed25519_deploy"
  - key_on_github: "Public key uploaded to GitHub account"
  - devcontainer_config_updated: "Mount and containerEnv added"
  - container_validation:
      - "echo $SSH_AUTH_SOCK  # /tmp/ssh-agent.socket"
      - "ssh-add -l  # Lists deploy key"
      - "ssh -T git@github.com  # Authenticates"
```

---

## Quick Reference: File→Line→Action

```yaml
"scripts/deploy_remote_devcontainer.sh":
  line_121:
    current: "rsync ... ${SSH_SYNC_SOURCE} ..."
    action: "ADD: --include='*.pub' --include='config' --include='known_hosts' --exclude='*'"
    risk: "LOW"
    breaking: false

"scripts/test_devcontainer_ssh.sh":
  line_112:
    current: "ssh -i \"$HOME/.ssh/id_ed25519\" -T git@github.com"
    action: "REPLACE with agent-aware version"
    risk: "LOW"
    breaking: false

".devcontainer/devcontainer.json":
  line_9:
    current: "\"runArgs\": [\"-p\", \"9222:2222\"]"
    action: "CHANGE to: [\"-p\", \"127.0.0.1:9222:2222\"]"
    risk: "MEDIUM"
    breaking: true
    requires: "SSH tunnel from Mac"

  after_line_22:
    action: "ADD mount for Remote-Resident Agent (optional)"
    content: "\"source=/home/rmanaloto/.ssh/agent.sock,target=/tmp/ssh-agent.socket,type=bind\""
    risk: "MEDIUM"
    requires: "ssh-agent service on remote host"

  in_containerEnv:
    action: "ADD SSH_AUTH_SOCK env var (optional)"
    content: "\"SSH_AUTH_SOCK\": \"/tmp/ssh-agent.socket\""
    risk: "MEDIUM"
    requires: "Mount configured first"

  after_line_34:
    action: "ADD Features for gh and awscli (optional)"
    features_to_add:
      - "ghcr.io/devcontainers/features/github-cli:1"
      - "ghcr.io/devcontainers/features/aws-cli:1"
    risk: "LOW"
    note: "Can then remove manual installs from Dockerfile"
```

---

**Document Version:** 1.0
**Format:** YAML-heavy for machine parsing
**Intended Audience:** AI agents, automation scripts, validation tools
