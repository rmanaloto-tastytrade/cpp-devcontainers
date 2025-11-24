# Local Environment Overrides

Use this directory to store machine- or host-specific settings for the devcontainer scripts. The file `devcontainer.env` is **not** tracked (see `.gitignore`). Populate it locally with the env vars you don’t want to pass on every command line.

## Example
Copy the template and edit values:
```bash
cp config/env/devcontainer.env.example config/env/devcontainer.env
```

`config/env/devcontainer.env.example`:
```bash
DEVCONTAINER_REMOTE_HOST=myhost.example.com
DEVCONTAINER_REMOTE_USER=myuser
DEVCONTAINER_SSH_PORT=9222
# Optional defaults:
# DEFAULT_REMOTE_HOST=myhost.example.com
# DEFAULT_REMOTE_USER=myuser
```

## How scripts use it
- `scripts/deploy_remote_devcontainer.sh`, `scripts/run_local_devcontainer.sh`, and `scripts/test_devcontainer_ssh.sh` will source `config/env/devcontainer.env` if it exists.
- Values from the env file provide defaults; explicit env/args still override.

## Notes
- Do not commit `config/env/devcontainer.env`; it is ignored.
- Keep sensitive data (API keys, private keys) out of this file; use your SSH agent/Keychain for keys.
