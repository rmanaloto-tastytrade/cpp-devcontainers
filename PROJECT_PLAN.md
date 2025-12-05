# Project Plan

1. **Environment & Tooling (Current phase)**  
   - **Priority: CMake/vcpkg workflow presets refresh** — see `docs/cmake_workflow.md` for the planned preset/toolchain model (C++26/C23 defaults, boost::ut tests, coverage/static-analysis/docs/package presets, per-permutation toolchain files).
   - Current status/details live in `docs/ai_devcontainer_workflow.md` (devcontainer matrix/build/verify) and `docs/ai_mutagen_runbook.md` (Mutagen setup/validation); the plan stays high-level here.  
   - **Priority: unblock Mutagen** – `scripts/verify_mutagen.sh`, `docs/mutagen-validation.md`, `docs/mutagen-research.md`. Blocker: Mutagen constructs a bad ssh command (`host` becomes literal `ssh`), so `sync create` fails even though plain SSH works. Next: run the Mutagen daemon in foreground with a logging ssh wrapper, enforce ssh command via `~/.mutagen.yml` or PATH-wrapped ssh, then re-run `verify_devcontainer.sh --require-ssh` with `REQUIRE_MUTAGEN=1` across all envs.  
   - **Remote Docker bake + devcontainer matrix** – all permutations built and verified on `c24s1.ch2` and `c090s4.ny5` (ports 9501–9506) using `scripts/run_local_devcontainer.sh` + `scripts/verify_devcontainer.sh --require-ssh`. Tooling present: clang/gcc variants, ninja, cmake, vcpkg, mrdocs, mutagen 0.18.1, all under `/usr/local`.  
   - **Hardening** – Dockerfile downloads now enforce SHA-256 checksums (ninja, mold, gh, ccache/sccache, ripgrep, node, mrdocs, jq, awscli, valgrind) and vcpkg post-create no longer tracks main unless `VCPKG_REF` is set; GitHub SSH is preseeded in known_hosts (no accept-new).  
   - **External AI review of devcontainer/toolchain validation** – run Codex/Claude/Gemini to audit Dockerfile/devcontainer/verify scripts for toolchain isolation; see `docs/ai_reviews/` for captured outputs and aggregate findings.
   - Clang branch mapping is centralized in `scripts/clang_branch_utils.sh` (stable→20, qualification→21, development→22) and flows through Dockerfile/bake/verify.  
   - Add/maintain workflow diagrams and ensure Dockerfile lint rules remain satisfied; keep package versions pinned once stable.  
   - Keep `docs/ai_devcontainer_workflow.md` and `docs/CURRENT_WORKFLOW.md` as the entry points for new agents.
   - Repo/sandbox paths now use the neutral cpp-devcontainers layout (e.g., `~/dev/github/SlotMap`, `~/dev/devcontainers/cpp-devcontainer`); keep new docs consistent.

2. **Policy & Concept Scaffolding**  
   - Formalize concepts in `include/slotmap/Concepts.hpp` for handles, slots, storage, and lookup.  
   - Provide default policies (growth, storage, lookup, instrumentation) backed by qlibs/stdx overlays.  
   - Document each policy in `docs/Policies/*.md` and illustrate flows in `docs/Diagrams/`.

3. **SlotMap Core Implementation**  
   - Implement handle generation, slot storage, and error propagation via `std::expected`/`boost::outcome::result`.  
   - Integrate Google Highway for SIMD-assisted scans where policy allows.  
   - Align `docs/Architecture/*.md` with real data-flow diagrams.

4. **Instrumentation & Logging**  
   - Wire Quill logging and policy-based tracing hooks.  
   - Introduce Intel CIB service registration for pluggable allocators/growth behaviors.

5. **Validation & Packaging**  
   - Expand unit coverage using `boost-ext/ut`, add sanitizers presets, and document release/deployment steps.  
   - Ensure `scripts/generate_docs.sh` artifacts feed CI/publishing.
