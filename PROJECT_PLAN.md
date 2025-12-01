# Project Plan

1. **Environment & Tooling (Current phase)**  
   - **Remote Docker bake + devcontainer matrix** – all permutations built and verified on `c24s1.ch2` and `c0903s4.ny5` (ports 9501–9506) using `scripts/run_local_devcontainer.sh` + `scripts/verify_devcontainer.sh --require-ssh`. Tooling present: clang/gcc variants, ninja, cmake, vcpkg, mrdocs, mutagen 0.18.1, all under `/usr/local`.  
   - Clang branch mapping is centralized in `scripts/clang_branch_utils.sh` (stable→20, qualification→21, development→22) and flows through Dockerfile/bake/verify.  
   - **Mutagen validation (in progress)** – `scripts/verify_mutagen.sh`, `docs/mutagen-validation.md`, `docs/mutagen-research.md`. Current blocker: Mutagen constructs a bad ssh command (`host` becomes literal `ssh`), so `sync create` fails; plain SSH works. Next: run the Mutagen daemon in foreground with a logging ssh wrapper, enforce ssh command via `~/.mutagen.yml` or PATH-wrapped ssh, then re-run `verify_devcontainer.sh --require-ssh` with `REQUIRE_MUTAGEN=1` across all envs.  
   - Add/maintain workflow diagrams and ensure Dockerfile lint rules remain satisfied; keep package versions pinned once stable.  
   - Keep `docs/ai_devcontainer_workflow.md` and `docs/CURRENT_WORKFLOW.md` as the entry points for new agents.

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
   - Expand gtest coverage, add sanitizers presets, and document release/deployment steps.  
   - Ensure `scripts/generate_docs.sh` artifacts feed CI/publishing.
