# AI_OPS

1. **Language & Toolchain** – All core code must target C++23 (with the option for C++26 experiments guarded by concepts). Use clang-21 and mold inside the devcontainer. No exceptions or RTTI; prefer `std::expected` / `boost::outcome::result` with policy-specific error enums.
2. **Policies First** – Every behavior change goes through a policy (growth, storage, lookup, instrumentation). Shared helpers belong under `include/slotmap/` or overlay packages (`qlibs`, `stdx`, `cib`).
3. **Documentation** – Whenever code changes land, update:
   - Markdown specs in `docs/Architecture/` and `docs/Policies/`.
   - Reference docs via `scripts/generate_docs.sh` (MRDocs + Doxygen + Graphviz + Mermaid).
   - Diagrams stored in `docs/Diagrams/`.
4. **Testing** – Keep unit tests in `tests/` aligned with the policy APIs. Tests run through the CMake preset `ctest --preset clang-debug`.
5. **Dependencies** – All third-party code enters through vcpkg manifests/overlays. Do not add ad-hoc submodules.
6. **Dev Experience** – CLion/vscode users rely on `.devcontainer/`. Any new tools must be wired into the container and documented in `README.md`.
7. **Validation cadence** – Run `scripts/pre_commit.sh` (bake/devcontainer lint + hadolint/shellcheck) and resolve failures before committing/pushing. Only instruct running remote build scripts after local validation passes.
