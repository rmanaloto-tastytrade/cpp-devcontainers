# SSH Configurations for Devcontainer Access

**Purpose:** Enumerate the SSH approaches we can use between laptop → remote host → devcontainer, with pros/cons. No changes applied; this is a reference for choosing a path.

## Options

### 1) Host SSH agent bind into devcontainer (current)
- **How:** Bind host `SSH_AUTH_SOCK` into the container (`/tmp/ssh-agent.socket`) and set `SSH_AUTH_SOCK` in the container env.
- **Pros:** Private keys stay on host; works for GitHub SSH; simple; no key copies.
- **Cons:** Requires host agent running; container SSH into GitHub depends on host connectivity/agent.
- **Best for:** Default secure workflow; least exposure.

### 2) Agent forwarding from laptop into container (jump through host)
- **How:** `ssh -A` from laptop to host, then into container; rely on laptop agent.
- **Pros:** Private keys stay on laptop; no host key copy.
- **Cons:** Breaks if laptop disconnects; brittle for long-running tasks; more hops.
- **Best for:** Ad hoc sessions when you don’t want host to hold keys.

### 3) Host-resident deploy key (agent on host)
- **How:** Generate a dedicated key on the host, load into host agent, bind agent into container.
- **Pros:** Isolates from laptop keys; revocable; host can operate without laptop.
- **Cons:** Another key to manage/rotate; still static key (unless certs).
- **Best for:** When host should operate independently of laptop.

### 4) Public-key staging only (no agent bind)
- **How:** Stage only `*.pub` into container authorized_keys; connect with an SSH client/key.
- **Pros:** No private key copy if you connect from laptop; simple.
- **Cons:** Container -> GitHub still needs a key/agent; typically still need agent bind for outbound.
- **Best for:** Inbound SSH to container when outbound GitHub is not needed.

### 5) Mounting private key material (not recommended)
- **How:** Bind-mount `~/.ssh` or private keys into container.
- **Pros:** Easy to “just work.”
- **Cons:** Private key exposure in container; theft risk; violates best practices.
- **Best for:** Avoid; only as temporary emergency with throwaway keys.

### 6) Cert-based access (Teleport/GitHub-issued certs)
- **How:** Use CA-signed short-lived certs (Teleport) or GitHub SSH certs; container binds agent holding certs.
- **Pros:** Ephemeral creds, auditability, SSO integration; no long-lived static keys.
- **Cons:** Requires CA/service setup; more moving parts.
- **Best for:** Org-wide hardened access with compliance needs.

## Port/Network Notes
- Use `ssh.github.com:443` for outbound GitHub SSH when port 22 is blocked.
- Publish container SSH port via devcontainer feature/runArgs; prefer configurability and localhost binding for tighter exposure.

## Recommended Default
- Keep private keys off the container; bind the host agent (`SSH_AUTH_SOCK`), and stage only public keys for inbound container SSH if needed. Consider cert-based auth if organizationally supported. Avoid mounting private key directories.
