## Devcontainer Docker Bake workflow

This page documents the planned multi-stage Dockerfile + `docker-bake.hcl` layout so we can review the flow before refactoring.

### Stages and responsibilities
- `base`: Ubuntu 24.04 with core OS/toolchain packages through `binutils+gdb` (includes Linux perf tooling, CMake, Ninja, Make, GCC, LLVM 21). Built/tagged once (e.g., `dev-base:local`) and reused by all other stages via `BASE_IMAGE`.
- Parallel builders (all `FROM base`) that install into staging prefixes for clean copying:
  - `clang_p2996` (Bloomberg compiler)
  - `node_mermaid` (Node.js tarball + `@mermaid-js/mermaid-cli`)
  - `mold`, `gh_cli`, `ccache`, `sccache`, `ripgrep`
  - `cppcheck`, `valgrind`
  - `python_tools` (uv, ruff, ty), `pixi`
  - `iwyu`, `mrdocs`
- `tools_merge`: `FROM base`; copies artifacts from all builder stages into `/usr/local` (and any required `/opt` prefixes), then bootstraps vcpkg and links `vcpkg` into `/usr/local/bin`.
- `devcontainer`: `FROM tools_merge`; creates the dev user, sets ownership, integrates vcpkg shells, and sets final env vars (CMD handled by devcontainer features instead of `sleep infinity`). Devcontainers should reference the baked image (e.g., `devcontainer:local`) in `devcontainer.json`.

### Workflow diagram
```mermaid
flowchart TB
    base[base\nOS + toolchains + perf + binutils/gdb]

    subgraph parallel_builds[parallel builders (FROM base)]
        direction LR
        clang_p2996[clang_p2996\nBloomberg clang]
        node_mermaid[node_mermaid\nNode.js + mermaid-cli]
        mold[mold]
        gh_cli[gh_cli]
        ccache[ccache]
        sccache[sccache]
        ripgrep[ripgrep]
        cppcheck[cppcheck]
        valgrind[valgrind]
        python_tools[python_tools\nuv / ruff / ty]
        pixi[pixi]
        iwyu[iwyu]
        mrdocs[mrdocs]
    end

    tools_merge[tools_merge\ncopy staged artifacts → /usr/local\n+ bootstrap vcpkg]
    devcontainer[devcontainer\nuser + env + shell integration]

    base --> parallel_builds
    clang_p2996 --> tools_merge
    node_mermaid --> tools_merge
    mold --> tools_merge
    gh_cli --> tools_merge
    ccache --> tools_merge
    sccache --> tools_merge
    ripgrep --> tools_merge
    cppcheck --> tools_merge
    valgrind --> tools_merge
    python_tools --> tools_merge
    pixi --> tools_merge
    iwyu --> tools_merge
    mrdocs --> tools_merge

    tools_merge --> devcontainer
```

### Bake targets (planned)
- `base`: builds the base image once; intended to be cached/reused to avoid rebuilds.
- `<builder>` targets for each parallel stage, plus a `tools` group target that depends on all builders.
- `tools_merge`: depends on `tools` (and runs vcpkg bootstrap).
- `devcontainer` (default): depends on `tools_merge`; final image for VS Code/CLion devcontainer. Devcontainers should reference this baked image via `image: devcontainer:local` in `devcontainer.json`, not rebuild locally.

### Caching & speedups
- Bake injects BuildKit cache import/export (`.docker/cache`) for all targets; run `docker buildx bake base` once to warm it, and subsequent `bake devcontainer` reuses layers.
- Heavy builds (clang_p2996, cppcheck, valgrind) use BuildKit cache mounts for their build directories; Node stage caches npm downloads.
- Keep tags stable (`BASE_TAG`, `TAG`) and bump only when versions change to maximize cache hits.
- Platform is controlled via `PLATFORM` (default `linux/amd64`) in `docker-bake.hcl`.
- Remote cache reuse is optional: when needed, add `--set *.cache-to=type=registry,ref=<reg>/dev-cache,mode=max --set *.cache-from=type=registry,ref=<reg>/dev-cache` to your bake command; by default only the local `.docker/cache` is used.

### Best practices to apply
- Use Buildx with `docker buildx bake` default builder; enable inline/registry cache (`cache-from`/`cache-to`) so base is pulled instead of rebuilt.
- Keep base thin but complete: all shared compilers/build deps live there; avoid duplicating apt installs in builders.
- Builders install into dedicated staging prefixes (e.g., `/opt/stage/<tool>` or `/tmp/stage/<tool>`) to simplify copy and keep layers deterministic.
- No `CMD ["sleep", "infinity"]` in the image—let devcontainer features or `postCreateCommand` handle runtime behavior.
- Use `args` in `docker-bake.hcl` for versions (clang, node, mold, etc.) to keep them overrideable without editing the Dockerfile.
- Keep dev-only settings in `devcontainer.json`/features (e.g., oh-my-zsh feature, SSHD feature already present); only bake image content, not runtime commands.
- Always run `scripts/pre_commit.sh` (bake/devcontainer validation + lint) before committing/pushing; only trigger remote rebuild scripts after these checks pass.
- Prefer Dev Container features for common tooling (SSH, shells, helpers) before adding Dockerfile steps; use bake args/targets for env-specific tweaks to keep the Dockerfile lean.
- Validation order: 1) run `scripts/pre_commit.sh` locally and fix issues; 2) commit/push; 3) trigger and wait for the Devcontainer Lint workflow to succeed; 4) only then run remote deploy/rebuild scripts.
