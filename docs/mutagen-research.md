# Mutagen Research Summary

Sources reviewed:
- https://mutagen.io/documentation/introduction/ (and tutorial sublinks)
- https://github.com/mutagen-io/mutagen
- https://github.com/mutagen-io/mutagen-compose
- https://github.com/mutagen-io/example-voting-app
- https://github.com/mutagen-io/fsevents
- https://www.datanovia.com/learn/tools/mutagen (tutorial series)
- Docker Desktop synchronized file sharing: https://docs.docker.com/desktop/features/synchronized-file-sharing/

Key takeaways:
- Transport:
  - Mutagen uses ssh by default; the first non-option token is the host. Custom ssh can be set via `MUTAGEN_SSH_COMMAND` or `sync.ssh.command` in `~/.mutagen.yml`.
  - The remote agent is staged under `.mutagen/agents/<version>/mutagen-agent` and launched via ssh.
  - Hostname errors often stem from malformed ssh command lines; wrappers must preserve `%h` position.
- Modes & flags:
  - `--sync-mode=two-way-resolved`, `--watch-mode=portable` recommended for dev.
  - `--ignore-vcs` to skip .git; `--name` to label sessions; `sync flush` to force propagation.
  - `MUTAGEN_LOG_LEVEL=debug` to diagnose transport/agent launch.
- macOS specifics:
  - Uses fsevents (see mutagen-io/fsevents) for change detection; falls back to polling if unavailable.
  - Docker Desktop offers built-in synchronized file sharing; Mutagen can be preferred for lower latency as long as mounts aren’t double-managed.
- Patterns from examples:
  - mutagen-compose: runs a sidecar container to manage sync for compose stacks.
  - example-voting-app: integrates Mutagen into the dev loop to populate app volumes.
  - mutagen repo tests show transport expects the host argument immediately after options; misplacement yields “Could not resolve hostname <token>”.

Gap observed in our environment:
- Mutagen agent launch shows `... ssh .mutagen/agents/...` with the host value literal `ssh`, leading to `Could not resolve hostname ssh`. We need to force the daemon to use a correct ssh command/host ordering.

Proposed fixes to try:
1) Add `~/.mutagen.yml` with:
   ```yaml
   sync:
     ssh:
       command: "/usr/bin/ssh -F /path/to/mutagen_ssh_config"
   ```
   where the config defines the ProxyJump/tunnel host so `%h` is correct.
2) Run `mutagen daemon run` in the foreground with a logging ssh wrapper to capture argv and confirm host placement.
3) After verified, bake a helper that writes the minimal ssh config for the active devcontainer env and restarts the daemon before running validations.
