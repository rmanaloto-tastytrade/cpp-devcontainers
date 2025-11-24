# TODO / Next Steps (Devcontainer)

**Branch:** modernization.20251118  
**Last updated:** 2025-11-24

- Parameterization done: host/user/port now configurable via env/args; devcontainer.json uses `${localEnv:DEVCONTAINER_SSH_PORT:-9222}`.
- SSH validation: GitHub SSH uses port 443 only; success banner treated as pass.
- Agent flow: host SSH agent bind into container; private keys stay on host; only host `~/.ssh/*.pub` staged for authorized_keys.
- Docs: SSH options and configurations documented in `docs/ssh-key-management-options.md` and `docs/ssh-configurations.md`.

Next steps (if picked up):
- Run `scripts/status_devcontainer.sh` to recall env/branch/logs after any interruption.
- If desired, remove remaining legacy Mac/host examples from other docs, or keep as examples.
- Optional: further harden SSH (cert-based, Teleport, or ssh-key-sync) if organization requires.
- Continue devcontainer tasks/tests as needed.

Reminder: keep changes committed/pushed frequently to preserve context. Use `logs/deploy_remote_devcontainer_*.log` to review last deploy output.
