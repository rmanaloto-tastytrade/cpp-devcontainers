# Aggregate Review: Devcontainer Toolchain Isolation

Sources:
- Claude (opus) — actionable findings (see claude_devcontainer_review.md).
- Codex — provided security/pinning/caching concerns (see codex_devcontainer_review.md).
- Gemini — no usable response (CLI silent; see gemini_devcontainer_review.md).

Key consolidated issues (from Claude + manual context):
1) Base image still installs gcc via PPA (gcc14) — base should be toolchain-agnostic; move compiler installs to permutation stages.
2) No dedicated permutation stages in Dockerfile — toolchains bleed; create explicit targets per permutation with their own CC/CXX/PATH and tool installs.
3) PATH/CC/CXX not set per permutation — avoid p2996/gcc15 bleed; set per target.
4) LLVM apt install per variant needs full package set and version gating; ensure libc++/abi match the clang variant.
5) verify_devcontainer PATH expectation overwritten by hardcoded p2996/gcc15 — remove duplicate assignment so permutation-aware list is used.
6) ENABLE_GCC15 set in base bake target — causes gcc15 bleed; default to 0 in base, enable only in gcc15 permutations.
7) IWYU commit/LLVM version hardcoded to clang_21 — align with CLANG_VARIANT per permutation.
8) Optional: containerEnv lacks CC/CXX.
9) Codex additional: pin downloads (curl installs) and apt repos; pin vcpkg commit; avoid broad buildx fs allow; scope caches per project; tighten SSH known_hosts/authorized_keys handling.

Next actions recommended:
- Refactor Dockerfile to add explicit permutation stages (gcc14/15 x clang21/22/p2996) that set CC/CXX/PATH and install only required toolchains (incl. libc++/abi for clang variants). Keep base minimal.
- Fix bake args: ENABLE_GCC15 default 0 in base; IWYU_COMMIT follow CLANG_VARIANT.
- Patch verify_devcontainer.sh to remove the hardcoded PATH override and add strict checks for extra/missing compilers/libc++.
- (Optional) Add CC/CXX to devcontainer.json containerEnv per permutation or set in post_create.
