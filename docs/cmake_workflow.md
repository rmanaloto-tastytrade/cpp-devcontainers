# CMake/vcpkg/Toolchain Workflow

This repo is driven by CMake presets and vcpkg; devcontainers only supply the toolchains. Use presets for all configure/build/test/package flows.

## Current wiring
- Presets (`CMakePresets.json`):
  - Base sets `CMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake`, overlays, C23/C++26, tests/docs on.
  - Chainload toolchains under `cmake/toolchains/*.cmake` for clang21/22/p2996 and gcc14/15.
  - Build/test presets map directly to configure presets; sanitizers exist for clang21/22; p2996 is debug-only today.
- Toolchains: pick explicit compilers under `/opt/clang-p2996/bin/clang++-p2996`, `/opt/gcc-15/bin/g++-15`, etc.
- vcpkg: `vcpkg.json` dependencies include fmt, ms-gsl, highway, quill, and an overlay port for bext-ut (plus overlay ports boost-ext-outcome, qlibs-core, stdx, cib).
- Tests: `boost::ut` (no gtest). `SLOTMAP_BUILD_TESTS` toggles them; `ctest` is invoked via test presets.
- Docs: custom `docs` target runs `scripts/generate_docs.sh` (mrdocs + doxygen), gated by `SLOTMAP_BUILD_DOCS`.
- Devcontainer independence: presets/toolchains are project-owned; images just need compilers at `/opt/clang-p2996`, `/opt/gcc-15`, LLVM apt toolchains, vcpkg root, ninja/cmake.

## Proposed workflow model (target state)
- **Presets as the single entry point** for all tasks:
  - Configure/build: Debug/Release/ASan/UBSan/Coverage per compiler (clang21/22/p2996, gcc14/15).
  - Test presets: `ctest --output-on-failure` on each configure preset.
  - Static analysis presets: clang-tidy, cppcheck, formatting check.
  - Coverage preset: build with coverage flags and run ctest + llvm-cov/gcovr report.
  - Package preset: CPack (tgz/zip/deb/rpm as needed).
  - Docs preset: invoke the existing `docs` target.
- **Toolchain files**: one per devcontainer permutation (already present for clang21/22/p2996, gcc14/15). Keep paths stable under `/opt/...` so devcontainers remain generic.
- **vcpkg**: rely on the existing manifests/overlays; bext-ut is provided via the overlay port and consumed through `find_package(ut CONFIG)`. No gtest dependency.
- **Automation/AI friendliness**:
  - Clear preset naming: `<compiler>-<config>-<purpose>` (e.g., `clang22-release`, `clang22-asan`, `gcc15-coverage`, `clang-p2996-debug`).
  - Ensure presets emit compile_commands.json, cache flags, and sensible defaults (warnings-as-errors on Debug).
  - Add helper script (optional) to list/run presets, but keep the source of truth in `CMakePresets.json`.
- **Devcontainer separation**: do not bake project builds into devcontainers. Containers only need the toolchains/vcpkg; all project workflows run via presets inside the container or CI.

## Immediate changes to implement
1) Expand presets to cover Release/ASan/UBSan/coverage/static-analysis/docs/package per compiler (including p2996).
2) Add test presets for each configure preset; ensure `ctest` uses `boost::ut` binary.
3) Add clang-tidy/cppcheck/format check presets and a coverage preset.
4) Keep toolchain files in sync with devcontainer images; add new toolchain files if new permutations are added.
5) Update CI (future) to run selected presets; keep devcontainer verification focused on toolchain availability.
