# Refactoring Roadmap: Safe Migration Path

**Version:** 1.0
**Last Updated:** 2025-01-22
**Target Completion:** Phased approach (Phase 1: 1 week, Phase 2-3: Optional)

---

## Overview

This document provides a **safe, tested, incremental** approach to implementing the security fixes and improvements identified in the security review.

**Guiding Principles:**
1. **No Big Bang** - Change one thing at a time
2. **Test Everything** - Validate after each step
3. **Easy Rollback** - Every change can be reverted independently
4. **Non-Breaking First** - Prioritize changes that don't break existing workflows
5. **Optional Enhancements** - Advanced features are clearly marked as optional

**Risk Management:**
- ✅ **LOW RISK** = Can deploy to production immediately after testing
- ⚠️ **MEDIUM RISK** = Requires user behavior change or additional setup
- 🔴 **HIGH RISK** = Major architectural change, extensive testing required

---

## Phase 1: Critical Security Fixes (MANDATORY)

**Timeline:** 1-2 days
**Risk Level:** ✅ LOW (non-breaking changes)
**Testing Required:** Standard validation only

### Milestone 1.1: Stop Syncing Private Keys

**Objective:** Fix the critical security vulnerability where private SSH keys are copied to the remote host

**Changes:**
1. File: `scripts/deploy_remote_devcontainer.sh`
2. Line: 121
3. Modification: Add rsync filters

**Implementation:**

```bash
# Before (current - line 121):
rsync -e "${RSYNC_SSH}" -av --chmod=F600,D700 \
  --rsync-path="mkdir -p ${REMOTE_SSH_SYNC_DIR} && rsync" \
  "${SSH_SYNC_SOURCE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SSH_SYNC_DIR}/"

# After (proposed):
rsync -e "${RSYNC_SSH}" -av --chmod=F600,D700 \
  --include='*.pub' --include='config' --include='known_hosts' --exclude='*' \
  --rsync-path="mkdir -p ${REMOTE_SSH_SYNC_DIR} && rsync" \
  "${SSH_SYNC_SOURCE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SSH_SYNC_DIR}/"
```

**Testing Plan:**

```bash
# 1. Dry run to verify only correct files are selected
rsync -e "ssh -o StrictHostKeyChecking=accept-new" -avn \
  --include='*.pub' --include='config' --include='known_hosts' --exclude='*' \
  ~/.ssh/ /tmp/rsync-test/

# Expected output: List of files to transfer
#   id_ed25519.pub
#   config
#   known_hosts
# NOT included: id_ed25519 (private key)

# 2. Create test branch
git checkout -b security-fix-rsync-filter

# 3. Make the change
vim scripts/deploy_remote_devcontainer.sh
# Edit line 121 as shown above

# 4. Commit
git add scripts/deploy_remote_devcontainer.sh
git commit -m "security: Restrict rsync to public keys only

- Only sync *.pub, config, and known_hosts files
- Exclude private keys (id_ed25519, id_rsa, etc.)
- Non-breaking change: workflow remains identical

Refs: docs/CRITICAL_FINDINGS.md Section 5.1"

# 5. Test deployment
./scripts/deploy_remote_devcontainer.sh

# 6. Verify no private keys on remote
ssh rmanaloto@c24s1.ch2 'ls -la ~/devcontainers/ssh_keys/'
# Expected: Only .pub files, config, known_hosts
# NOT present: id_ed25519, id_rsa

# 7. Verify container still works
ssh -i ~/.ssh/id_ed25519 -p 9222 rmanaloto@c24s1.ch2 'echo SUCCESS'

# 8. Verify GitHub access (currently uses bind-mounted key - Phase 2 will fix)
ssh -p 9222 rmanaloto@c24s1.ch2 'ssh -T git@github.com'
# Expected: Still works (uses Mac's private key via SSH agent forwarding in next milestone)
```

**Rollback Plan:**
```bash
git revert HEAD
./scripts/deploy_remote_devcontainer.sh
```

**Success Criteria:**
- ✅ Private keys NOT present on remote host
- ✅ Public keys present on remote host
- ✅ SSH connection to container works
- ✅ Container build succeeds
- ✅ All tools available in container

**Blockers:** None

---

### Milestone 1.2: Enable SSH Agent Forwarding

**Objective:** Allow container to use Mac's SSH agent for GitHub operations instead of bind-mounted private key

**Changes:**
1. File: `scripts/test_devcontainer_ssh.sh`
2. Line: 112
3. Modification: Detect and use SSH agent if available

**Implementation:**

```bash
# Before (current - line 112):
ssh -F /dev/null -i "$HOME/.ssh/id_ed25519" ... -T git@github.com || true

# After (proposed):
if ssh-add -l >/dev/null 2>&1; then
    echo "[ssh-remote] Testing GitHub SSH via agent forwarding"
    ssh -T git@github.com 2>&1 || echo "[ssh-remote] Note: Agent forwarding may not be configured"
else
    echo "[ssh-remote] WARNING: No SSH agent available"
    echo "[ssh-remote] INFO: You can enable agent forwarding with:"
    echo "[ssh-remote]   1. On Mac: eval \"\$(ssh-agent -s)\" && ssh-add ~/.ssh/id_ed25519"
    echo "[ssh-remote]   2. Connect with: ssh -A -p 9222 rmanaloto@c24s1.ch2"
fi
```

**Testing Plan:**

```bash
# 1. Create test branch (or continue from Milestone 1.1)
git checkout -b security-fix-agent-forwarding

# 2. Make the change
vim scripts/test_devcontainer_ssh.sh
# Edit line 112 as shown above

# 3. Commit
git add scripts/test_devcontainer_ssh.sh
git commit -m "security: Support SSH agent forwarding for GitHub auth

- Test script now uses SSH agent if available
- Falls back gracefully if agent not configured
- Backward compatible: works with or without agent

Refs: docs/CRITICAL_FINDINGS.md Section 5.1.2"

# 4. Test WITHOUT agent (verify backward compatibility)
./scripts/deploy_remote_devcontainer.sh
# Should print warning about no agent, but not fail

# 5. Test WITH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# 6. Connect with agent forwarding
ssh -A -p 9222 rmanaloto@c24s1.ch2 << 'EOF'
echo "[test] Checking agent availability"
if ssh-add -l; then
    echo "[test] SUCCESS: Agent is forwarded"
    echo "[test] Testing GitHub connection"
    ssh -T git@github.com
else
    echo "[test] FAIL: Agent not forwarded"
    exit 1
fi
EOF
```

**User Documentation Update:**

Create file: `docs/SSH_AGENT_FORWARDING.md`

```markdown
# SSH Agent Forwarding for Devcontainer

## Overview
Instead of copying your private SSH key to the remote host, you can use SSH agent forwarding
to allow the container to use your Mac's SSH agent.

## Setup

### On Mac (one-time):
\`\`\`bash
# Start ssh-agent
eval "$(ssh-agent -s)"

# Add your key
ssh-add ~/.ssh/id_ed25519

# Verify key is loaded
ssh-add -l
\`\`\`

### Configure SSH (optional):
Add to `~/.ssh/config`:
\`\`\`
Host c24s1.ch2
    ForwardAgent yes
    IdentityFile ~/.ssh/id_ed25519
\`\`\`

### Connect with Forwarding:
\`\`\`bash
# Method 1: Explicit flag
ssh -A -p 9222 rmanaloto@c24s1.ch2

# Method 2: If configured in ~/.ssh/config
ssh -p 9222 rmanaloto@c24s1.ch2
\`\`\`

### Verify in Container:
\`\`\`bash
# Check agent socket
echo $SSH_AUTH_SOCK
# Output: /tmp/ssh-XXX/agent.XXX

# List keys
ssh-add -l
# Output: Your key fingerprint

# Test GitHub
ssh -T git@github.com
# Output: Hi <username>! You've successfully authenticated...
\`\`\`

## Troubleshooting

**Agent socket not set:**
- Reconnect with `ssh -A` flag
- Check `AllowAgentForwarding yes` in remote sshd_config

**Key not listed:**
- Run `ssh-add ~/.ssh/id_ed25519` on Mac before connecting

**GitHub auth fails:**
- Verify key is added to GitHub account: https://github.com/settings/keys
\`\`\`

**Rollback Plan:**
```bash
git revert HEAD  # Reverts to using private key directly
./scripts/deploy_remote_devcontainer.sh
```

**Success Criteria:**
- ✅ With agent: GitHub authentication works
- ✅ Without agent: Prints helpful warning message
- ✅ Test script doesn't fail either way

**Blockers:** None (backward compatible)

---

### Milestone 1.3: Remove SSH Keys Bind Mount

**Objective:** Stop bind-mounting `~/devcontainers/ssh_keys` into container

**Changes:**
1. File: `.devcontainer/devcontainer.json`
2. Line: 22
3. Modification: Comment out or remove SSH keys bind mount

**Prerequisites:**
- ✅ Milestone 1.1 complete (private keys not synced)
- ✅ Milestone 1.2 complete (agent forwarding works)
- ✅ Users have configured agent forwarding

**Implementation:**

```json
// Before (current - line 22):
"mounts": [
  "source=slotmap-vcpkg,target=/opt/vcpkg/downloads,type=volume",
  "source=${localEnv:REMOTE_SSH_SYNC_DIR},target=/home/${env:DEVCONTAINER_USER}/.ssh,type=bind,consistency=cached"
],

// After (proposed):
"mounts": [
  "source=slotmap-vcpkg,target=/opt/vcpkg/downloads,type=volume"
  // SSH keys mount REMOVED - using agent forwarding instead
  // If you need the mount for some reason, uncomment below:
  // "source=${localEnv:REMOTE_SSH_SYNC_DIR},target=/home/${env:DEVCONTAINER_USER}/.ssh-backup,type=bind,consistency=cached"
],
```

**Testing Plan:**

```bash
# 1. Create test branch
git checkout -b security-remove-ssh-mount

# 2. Make the change
vim .devcontainer/devcontainer.json
# Remove line 22 or comment it out

# 3. Commit
git add .devcontainer/devcontainer.json
git commit -m "security: Remove SSH keys bind mount

- Container no longer has direct access to SSH keys
- Users must use SSH agent forwarding for GitHub operations
- Breaking change: Requires agent forwarding (see docs/SSH_AGENT_FORWARDING.md)

Refs: docs/CRITICAL_FINDINGS.md Section 5.1.3"

# 4. Test deployment
./scripts/deploy_remote_devcontainer.sh

# 5. Verify mount is gone
ssh -p 9222 rmanaloto@c24s1.ch2 'ls -la ~/.ssh/'
# Expected: Directory exists (created by sshd feature) but is empty or only has authorized_keys

# 6. Verify agent forwarding required
ssh -p 9222 rmanaloto@c24s1.ch2 'ssh -T git@github.com'
# Expected: Fails if agent not forwarded

# 7. Test with agent forwarding
ssh -A -p 9222 rmanaloto@c24s1.ch2 'ssh -T git@github.com'
# Expected: Success

# 8. Test git operations
ssh -A -p 9222 rmanaloto@c24s1.ch2 << 'EOF'
cd ~/workspace
git status
# Should work (reads from workspace)

echo "test" > test.txt
git add test.txt
git commit -m "test"
# Should work if agent forwarded

git push origin HEAD
# Should work if agent forwarded
EOF
```

**User Communication:**

**⚠️ BREAKING CHANGE - Announce to team:**

```
SUBJECT: Security Update: SSH Agent Forwarding Now Required

We've completed a security audit of our devcontainer setup and discovered
that SSH private keys were being copied to the remote host, creating a
security vulnerability.

WHAT CHANGED:
- Private keys are no longer synced to the remote host
- Container no longer has access to your SSH keys via bind mount
- You must use SSH agent forwarding for GitHub operations

HOW TO UPDATE YOUR WORKFLOW:
1. On your Mac, start ssh-agent and add your key:
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519

2. Connect with agent forwarding enabled:
   ssh -A -p 9222 rmanaloto@c24s1.ch2

3. Verify it works:
   ssh -T git@github.com

See docs/SSH_AGENT_FORWARDING.md for full instructions.

TIMELINE:
- Testing: This week
- Deployment: Next Monday
- Support: #devops channel

Questions? Ask in #devops or see the documentation.
```

**Rollback Plan:**
```bash
git revert HEAD
./scripts/deploy_remote_devcontainer.sh
# Note: Users' private keys were already removed in Milestone 1.1
# To fully rollback, revert Milestone 1.1 as well
```

**Success Criteria:**
- ✅ SSH keys NOT bind-mounted into container
- ✅ `~/.ssh/` in container is empty (except authorized_keys)
- ✅ Git operations work with agent forwarding
- ✅ Git operations fail WITHOUT agent forwarding (expected)
- ✅ Documentation updated

**Blockers:**
- All users must be notified and have docs
- Team meeting to explain the change
- Support channel ready for questions

---

## Phase 2: Optional Enhancements (RECOMMENDED)

**Timeline:** 1-2 weeks
**Risk Level:** ⚠️ MEDIUM (requires additional setup)
**Testing Required:** Extensive validation, user acceptance testing

### Milestone 2.1: Remote-Resident SSH Agent (OPTIONAL)

**Objective:** Support GitHub access when Mac is offline (for long-running builds, CI/CD, etc.)

**When to implement:**
- Long-running builds (>1 hour) that need Git access
- Automated workflows that run while you're offline
- Team members who disconnect frequently
- CI/CD pipelines using the same container setup

**When NOT to implement:**
- Interactive development only
- Short builds (<1 hour)
- Always-connected workflow
- Security policy forbids keys on remote host

**Implementation:**

See `docs/CRITICAL_FINDINGS.md` Section 5 "Phase 2: Remote-Resident Agent" for detailed steps.

**Summary:**
1. Create systemd service on remote host to run ssh-agent
2. Generate separate deploy key for GitHub
3. Add deploy key to GitHub account (read-only if possible)
4. Configure devcontainer.json to bind-mount agent socket
5. Test and document

**Risk:** ⚠️ MEDIUM
- Requires separate deploy key management
- Key lives on remote host (though only in agent memory)
- Additional configuration complexity

**Rollback Plan:**
```bash
# Disable systemd service
systemctl --user disable ssh-agent
systemctl --user stop ssh-agent

# Remove mount from devcontainer.json
git revert <commit>
./scripts/deploy_remote_devcontainer.sh
```

---

### Milestone 2.2: Bind Port to Localhost (OPTIONAL)

**Objective:** Reduce attack surface by only exposing SSH port to localhost

**Changes:**
1. File: `.devcontainer/devcontainer.json`
2. Line: 9
3. Modification: Bind port to 127.0.0.1 instead of 0.0.0.0

**Implementation:**

```json
// Before:
"runArgs": ["-p", "9222:2222"]

// After:
"runArgs": ["-p", "127.0.0.1:9222:2222"]
```

**User Workflow Change:**

```bash
# Step 1: Create SSH tunnel from Mac
ssh -L 9222:localhost:9222 rmanaloto@c24s1.ch2 -N -f

# Step 2: Connect to container via localhost
ssh -p 9222 rmanaloto@localhost

# Step 3: Use IDE remote features via localhost:9222
```

**Risk:** ⚠️ MEDIUM
- Requires user behavior change
- Adds extra step (SSH tunnel)
- May confuse new users

**Benefits:**
- Port not exposed on network
- Requires access to remote host first
- Defense in depth

**Rollback Plan:**
```bash
git revert HEAD
./scripts/deploy_remote_devcontainer.sh
```

---

### Milestone 2.3: Replace gh CLI with Feature (OPTIONAL)

**Objective:** Simplify Dockerfile by using official devcontainer Feature for gh CLI

**Changes:**
1. File: `.devcontainer/devcontainer.json` - Add feature
2. File: `.devcontainer/Dockerfile` - Remove manual install

**Implementation:**

```json
// .devcontainer/devcontainer.json - Add to features section:
"features": {
  "ghcr.io/devcontainers/features/sshd:1": {
    // ... existing config ...
  },
  "ghcr.io/devcontainers/features/github-cli:1": {
    "version": "latest"
  },
  "ghcr.io/devcontainers/features/aws-cli:1": {
    "version": "latest"
  }
}
```

```dockerfile
# .devcontainer/Dockerfile - REMOVE these sections:
# ... lines installing gh CLI manually ...
# ... lines installing awscli manually ...
```

**Testing Plan:**

```bash
# 1. Add features to devcontainer.json
# 2. Rebuild container
./scripts/deploy_remote_devcontainer.sh

# 3. Verify tools work
ssh -p 9222 rmanaloto@c24s1.ch2 'gh --version && aws --version'

# 4. If successful, remove manual installs from Dockerfile
# 5. Rebuild and verify again
```

**Risk:** ✅ LOW
- Feature versions may differ from manual installs
- Should work but test thoroughly

**Rollback Plan:**
```bash
git revert HEAD
./scripts/deploy_remote_devcontainer.sh
```

---

## Phase 3: Advanced Improvements (OPTIONAL)

**Timeline:** As needed
**Risk Level:** 🔴 HIGH (major changes)
**Testing Required:** Extensive, possibly on separate environment

### Potential Future Work

1. **Separate Keys Per Purpose**
   - `id_ed25519_remote` for remote host access
   - `id_ed25519_container` for container access
   - `id_ed25519_github` for GitHub operations

2. **Automated Security Scanning**
   - Pre-commit hooks to detect private keys
   - Docker image vulnerability scanning
   - Secrets detection in git commits

3. **Monitoring & Alerting**
   - SSH access logs
   - GitHub API usage auditing
   - Container resource monitoring

4. **Multi-User Support**
   - Namespace isolation per user
   - Resource quotas
   - Shared cache optimization

**Note:** These are not prioritized and should only be implemented if there's a clear business need.

---

## Migration Schedule

### Week 1: Phase 1 (Critical Security)

```
Day 1: Milestone 1.1 (Stop syncing private keys)
  - Morning: Implement & test on dev environment
  - Afternoon: Code review & approval
  - Deploy to test branch

Day 2: Milestone 1.2 (SSH agent forwarding)
  - Morning: Implement & test
  - Afternoon: Write user documentation
  - Deploy to test branch

Day 3: Testing & Documentation
  - Full integration test of Phase 1
  - Update README with new workflow
  - Create SSH_AGENT_FORWARDING.md

Day 4: Team Communication
  - Team meeting to explain changes
  - Answer questions
  - Ensure everyone understands new workflow

Day 5: Production Deployment & Support
  - Merge to main
  - Deploy to production
  - Monitor for issues
  - Provide support in #devops channel
```

### Week 2-3: Phase 2 (Optional Enhancements)

```
Optional: Implement Milestones 2.1-2.3 based on team needs
```

---

## Success Metrics

### Phase 1 Completion Criteria

- ✅ Private keys NOT present on remote filesystem
- ✅ Private keys NOT bind-mounted into containers
- ✅ All users can connect and work with agent forwarding
- ✅ GitHub operations work with agent forwarding
- ✅ Build process unchanged and working
- ✅ Zero security regressions
- ✅ Documentation complete and clear
- ✅ Team trained and comfortable with new workflow

### Measurements

```yaml
security_improvements:
  - metric: "Private keys on remote filesystem"
    before: "Present in ~/devcontainers/ssh_keys/"
    after: "Not present"
    status: "PASS"

  - metric: "Private keys in container"
    before: "Bind-mounted to ~/.ssh/"
    after: "Not accessible"
    status: "PASS"

  - metric: "Attack surface"
    before: "Private key accessible to root, backups, container processes"
    after: "Private key only on Mac, never leaves local machine"
    status: "PASS"

workflow_impact:
  - metric: "Build time"
    before: "45-65 minutes (cold), 3-5 minutes (cached)"
    after: "45-65 minutes (cold), 3-5 minutes (cached)"
    status: "NO CHANGE (good)"

  - metric: "User steps to connect"
    before: "1 command: ssh -p 9222 rmanaloto@c24s1.ch2"
    after: "2 commands: eval $(ssh-agent -s) && ssh-add && ssh -A -p 9222 rmanaloto@c24s1.ch2"
    status: "1 extra step (acceptable for security)"

  - metric: "Documentation quality"
    before: "Limited security documentation"
    after: "Comprehensive docs with troubleshooting"
    status: "IMPROVED"
```

---

## Contingency Plans

### If Phase 1 Breaks Production

**Symptoms:** Users cannot connect, builds fail, Git operations don't work

**Immediate Response:**
```bash
# 1. Emergency rollback
git revert <failing-commit>
./scripts/deploy_remote_devcontainer.sh

# 2. Notify team
# 3. Investigate root cause
# 4. Fix and re-test before re-deploying
```

### If Agent Forwarding Doesn't Work for Some Users

**Possible Causes:**
- SSH agent not started
- Key not added to agent
- ForwardAgent disabled
- Remote sshd_config blocks forwarding

**Solutions:**
1. Document common issues in SSH_AGENT_FORWARDING.md
2. Create troubleshooting flowchart
3. Provide one-on-one support as needed
4. Consider temporary fallback (but keep security fix)

### If Remote-Resident Agent Fails

**Risk:** Deploy key compromised, agent crashes, socket permissions wrong

**Mitigation:**
- Use read-only deploy key on GitHub
- Monitor GitHub audit log for unusual activity
- Rotate keys quarterly
- Document recovery procedure
- Have emergency revocation process

---

## Communication Plan

### Stakeholders

```yaml
engineering_team:
  notification: "Email + Slack + Team meeting"
  docs: "docs/SSH_AGENT_FORWARDING.md"
  support: "#devops channel"
  timeline: "1 week notice before deployment"

devops_team:
  notification: "Email + Slack"
  docs: "docs/CRITICAL_FINDINGS.md + REFACTORING_ROADMAP.md"
  support: "Direct communication"
  timeline: "Immediate (they implement it)"

management:
  notification: "Email summary"
  docs: "Executive summary of security improvement"
  support: "As needed"
  timeline: "After successful deployment"
```

### Key Messages

**To Engineering:**
> We've fixed a security vulnerability where SSH private keys were being copied to the remote server.
> You'll need to use SSH agent forwarding going forward. It's one extra command but much more secure.
> See docs/SSH_AGENT_FORWARDING.md for details.

**To Management:**
> Security audit revealed private SSH keys were exposed on remote infrastructure.
> Issue has been fixed with zero impact to productivity.
> Improvement aligns with industry best practices for secret management.

---

## Appendix: Testing Checklist

### Pre-Deployment Testing

- [ ] Dry-run rsync filter to verify only public keys synced
- [ ] Test build with new configuration
- [ ] Verify container starts correctly
- [ ] Test SSH connection to container
- [ ] Test agent forwarding with GitHub
- [ ] Test git operations (clone, commit, push)
- [ ] Verify all development tools work
- [ ] Test on multiple user machines
- [ ] Document any edge cases discovered

### Post-Deployment Monitoring

- [ ] Monitor #devops channel for user issues
- [ ] Check error logs for authentication failures
- [ ] Verify no private keys on remote filesystem
- [ ] Conduct spot checks with random sampling
- [ ] Collect user feedback after 1 week
- [ ] Update documentation based on feedback

---

**Document Version:** 1.0
**Status:** Ready for Implementation
**Approval Required:** DevOps Lead, Security Team
