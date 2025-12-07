# Aggregate: prevent docker.io fallback on devcontainer builds

Sources: codex, claude, gemini, cursor-agent (2025-12-07).

- Root cause: unqualified base tag (`cpp-cpp-dev-base:local`) made BuildKit fall back to docker.io/library; base not guaranteed built/loaded before permutations.
- Tagging/args: use GHCR FQIN for base (`ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/cpp-dev-base:local`) and pass via `BASE_IMAGE` arg from bake/workflow. Keep local aliases only as secondary tags, never primary.
- Build order: bake/build the base target first with `load: true`, `push: false` (or push to GHCR on main). Then run permutation targets using the loaded base; set `pull: false` so BuildKit won’t reach docker.io.
- Bake config: set base target tags to GHCR + localhost alias; set permutation targets `args.BASE_IMAGE=${BASE_TAG}`; ensure cache-from/to use GHCR refs (optionally registry cache ref); keep context=workspace.
- Workflow guards: export `BASE_TAG`/`BASE_IMAGE` env before bake; add validation step to fail if any tag matches docker.io or lacks registry; `grep` baked JSON for docker.io. Use `pull: false` in bake-action.
- Cache: allow local cache dir plus GHCR cache refs (`type=registry,ref=ghcr.io/...:cache,mode=max`) on main; avoid docker.io entirely.
