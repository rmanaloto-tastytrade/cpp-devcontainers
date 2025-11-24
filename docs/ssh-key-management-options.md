# SSH Key Management Options (Review)

**Purpose:** Compare approaches for handling SSH keys between your laptop, the remote host, and the devcontainer. Current setup uses the host SSH agent (bound into the container) and stages only public keys; private keys stay on the host.

## What we do today
- Private keys remain on the remote host; only `~/.ssh/*.pub` are staged into `.devcontainer/ssh` for authorized_keys.
- The devcontainer binds the host `SSH_AUTH_SOCK` (`/tmp/ssh-agent.socket`) so outbound GitHub SSH uses the host agent.
- No Mac keys are copied to the remote host.

## Tooling Options (Pros/Cons)

### 1) Teleport (https://goteleport.com/blog/ssh-key-management/)
- **What it is:** Centralized access plane with short-lived certificates (CA-signed), SSO integration.
- **Pros:** Ephemeral certs (no long-lived keys), audit, role-based access, hardware key support.
- **Cons:** Operates as an infra service (heavier than simple SSH), setup/ops overhead, vendor lock-in concerns.
- **Fit here:** Strong for org-wide access control; overkill if you just need devcontainer auth.

### 2) ssh-key-sync (https://github.com/shoenig/ssh-key-sync)
- **What it is:** Push/pull public keys to remote hosts via a simple CLI; manages authorized_keys updates.
- **Pros:** Lightweight, Git-friendly key repo, avoids copying private keys.
- **Cons:** Still static public keys; no certs/SSO; requires running the sync tool.
- **Fit here:** Good for keeping authorized_keys in sync across hosts without rsyncing private keys.

### 3) ssh-sync (https://sshsync.io/)
- **What it is:** Service to sync SSH keys/authorized_keys; SaaS-style automation.
- **Pros:** Automates key distribution, supports teams.
- **Cons:** External service dependency, trust/tenancy considerations.
- **Fit here:** Similar to ssh-key-sync but outsourced; evaluate org policy before use.

### 4) ssh-copy-id (standard OpenSSH)
- **What it is:** Built-in helper to install public keys into authorized_keys.
- **Pros:** Ubiquitous, simple, no private key copy, no extra deps.
- **Cons:** One-time install; doesn’t manage revocation/rotation across many hosts.
- **Fit here:** Ideal for ad-hoc provisioning of public keys to remote hosts; aligns with keeping private keys local.

### 5) rsync + Unison/Syncthing (https://en.wikipedia.org/wiki/Unison_%28software%29)
- **What it is:** File sync tools; could sync `authorized_keys` or `~/.ssh`.
- **Pros:** Bi/uni-directional sync, resilient to conflicts (Unison).
- **Cons:** High risk if syncing private keys; complexity not justified just for key distro; better to avoid syncing `~/.ssh`.
- **Fit here:** Not recommended for private keys; only consider for a controlled public-key repo.

### 6) ssh-key-authority (https://github.com/operasoftware/ssh-key-authority)
- **What it is:** Central management of authorized_keys via an API/backing store.
- **Pros:** Centralized key distribution, revocation, auditing.
- **Cons:** Another service to run/maintain; still static keys (no certs).
- **Fit here:** Good if you want a self-hosted key management service without full Teleport; more overhead than ssh-copy-id/key-sync.

## Recommendations for this project
1) **Keep private keys on the host**; continue binding the host agent into the devcontainer. No private-key sync.
2) **Use ssh-copy-id or ssh-key-sync** to distribute public keys to remote hosts (authorized_keys) instead of any rsync of `~/.ssh`.
3) If you need org-wide lifecycle (rotation, audit, SSO): consider **Teleport** (cert-based) or a self-hosted option like **ssh-key-authority**. Otherwise, stay with lightweight public-key tooling.
4) Avoid Unison/Syncthing/rsync for `~/.ssh` (risk of syncing private keys). Only sync a curated public-key set if needed.

## Next steps (optional)
- Replace any remaining key staging paths with a public-key installer (ssh-copy-id or ssh-key-sync).
- Keep agent forwarding/agent bind as the default for container GitHub access.
- If compliance/audit is required, evaluate Teleport vs. ssh-key-authority and document the chosen path.
