# Devcontainer Image Optimization Plan

**Scope:** Keep the current Bake pipeline (base → tools_merge → devcontainer), retain `devcontainer.json` runtime settings, and improve size/rebuild speed without changing runtime behavior.

## Current build artifacts (Bake)
- `base` (`cpp-dev-base:local`): Ubuntu 24.04 + core deps, toolchain repos, GCC-${GCC_VERSION} (currently 14), LLVM/clang-21 from llvm.sh, binutils+gdb.
- Parallel tool stages (15): clang_p2996, node_mermaid, mold, gh_cli, ccache, sccache, ripgrep, cppcheck, valgrind, python_tools, pixi, iwyu, mrdocs, jq, awscli.
- `tools_merge`: merges staged tool outputs.
- `devcontainer` (`cpp-devcontainer:local`): final image with user/uid/gid, mounts, agent socket, sshd feature.

## Observations
- GCC: only GCC-${GCC_VERSION} (14) is installed; no GCC-13 present. No action needed to remove GCC-13, but keep a periodic check to avoid drift.
- llvm.sh installs clang-21 and dev libs; aliasing for clang_p2996 is already isolated (`clang-p2996`, `clang++-p2996`).
- Large builders (cost/size): clang_p2996 (full LLVM build), valgrind, cppcheck, binutils+gdb, node+mermaid, llvm.sh extras (bolt/flang/mlir/libc components).

## Size/maintenance reduction plan (no changes yet)
1) **Package audit (base stage)**
   - Verify necessity of full llvm.sh add-ons: `bolt`, `flang`, `libclc`, `libunwind`, `libllvmlibc`, `mlir` dev/tool packages. Consider toggling these via build args if not required for day-to-day dev.
   - Confirm all build-essential extras (texinfo, m4, autoconf-archive) are still needed; move rarely-used tooling behind optional args.
2) **Strip and clean**
   - Ensure every source-built stage already deletes build dirs (most do). Add explicit `strip`/`--strip-unneeded` on large binaries where safe (binutils/gdb builds, custom clang_p2996 install, mold, cppcheck).
   - Recheck apt cleanups; base already does `rm -rf /var/lib/apt/lists/*`, keep that pattern.
3) **Optional tool toggles (keep defaults ON initially)**
   - Add build args to skip heavyweight tools (valgrind, cppcheck, iwyu, clang_p2996) for lightweight images when needed, while keeping the default profile identical.
   - Add a `slim` group in bake that omits optional targets; leave `default` unchanged.
4) **Version-bump hygiene**
   - Document a “version bump checklist” (llvm.sh `LLVM_VERSION`, Node/mermaid, mold, gh_cli, jq, pixi, awscli, clang_p2996 branch) so upgrades are deliberate and tested.
   - Keep version args centralized in `docker-bake.hcl`; add a small `scripts/check_tool_versions.sh` to diff a manifest vs Dockerfile args before bumping.
5) **Cache and rebuild speed**
   - Keep `cpp-dev-base:local` cached; consider publishing/pulling it when working across hosts.
   - Use per-target rebuilds for updates: `docker buildx bake <tool>` then `docker buildx bake devcontainer`.
   - Maintain vcpkg cache volume; optionally add ccache/sccache volumes for iterative builds.
6) **Image inspection**
   - Add a `scripts/inspect_image_sizes.sh` to report layer sizes for `cpp-dev-base:local` and `cpp-devcontainer:local` to track progress without changing builds.

## Next steps (if approved)
- Implement optional tool toggles and “slim” bake group (defaults unchanged).
- Add version bump checklist + `check_tool_versions` helper.
- Add size inspection helper to monitor impact.
- Evaluate trimming llvm.sh extras if not required by current workflows/tests.
