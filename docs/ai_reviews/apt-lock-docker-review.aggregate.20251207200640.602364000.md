# Apt cache locking review (Dockerfile/docker-bake)

Sources:
- codex.apt-lock-docker-review.*
- claude.apt-lock-docker-review.*
- gemini.apt-lock-docker-review.*
- cursor-agent.apt-lock-docker-review.*

Findings (all agents agreed unless noted):
- Missing locked apt cache mounts on LLVM/Clang ensure blocks in both base stage and final devcontainer stage (`apt-get update/install clang-${CLANG_VARIANT}`) – add `--mount=type=cache,target=/var/cache/apt,sharing=locked` and `/var/lib/apt/lists`.
- Missing locked apt cache mounts on valgrind fallback `apt-get` install – add the same mounts.
- (Gemini-only) Warns that clearing `/var/lib/apt/lists/*` defeats list caching; consider keeping cleanup only on non-cached mounts if we want reuse.
- Optional: DRY the duplicated LLVM install blocks across stages.

Next steps:
1) Add locked apt cache mounts to LLVM ensure blocks (base + devcontainer) and valgrind fallback.
2) Decide whether to keep/remove `rm -rf /var/lib/apt/lists/*` when using cache mounts; if keeping cleanup for image size, accept slower rebuilds or split cache vs cleanup.
3) Consider factoring shared LLVM install logic to reduce drift.
