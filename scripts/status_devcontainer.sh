#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "== Devcontainer Status =="
echo "Branch        : $(git rev-parse --abbrev-ref HEAD)"
echo "Dirty         : $(if [[ -n $(git status --porcelain) ]]; then echo yes; else echo no; fi)"
echo
echo "Env (defaults if unset):"
echo "  DEVCONTAINER_REMOTE_HOST : ${DEVCONTAINER_REMOTE_HOST:-<unset>}"
echo "  DEVCONTAINER_REMOTE_USER : ${DEVCONTAINER_REMOTE_USER:-<unset>}"
echo "  DEVCONTAINER_SSH_PORT    : ${DEVCONTAINER_SSH_PORT:-9222}"
echo
echo "Recent deploy logs (latest 5):"
ls -1t "$REPO_ROOT/logs"/deploy_remote_devcontainer_*.log 2>/dev/null | head -n5 || echo "  (none)"
echo
echo "Command reminders:"
echo "  Deploy: DEVCONTAINER_REMOTE_HOST=<host> DEVCONTAINER_REMOTE_USER=<user> DEVCONTAINER_SSH_PORT=<port> ./scripts/deploy_remote_devcontainer.sh"
echo "  Test  : DEVCONTAINER_REMOTE_HOST=<host> DEVCONTAINER_REMOTE_USER=<user> DEVCONTAINER_SSH_PORT=<port> ./scripts/test_devcontainer_ssh.sh --host <host> --user <user> --port <port> --key <path> --clear-known-host"
