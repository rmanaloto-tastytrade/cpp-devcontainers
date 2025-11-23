# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Modern C++23/26 SlotMap container implementation using a policy-driven architecture. This is a header-only library with strict error handling (no exceptions, uses `std::expected`/`boost::outcome::result`), SIMD acceleration via Google Highway, and service wiring through Intel CIB.

**Core Architecture Components:**
- **Handles**: 64-bit values (generation + slot index) validated through typed results
- **Policy System**: Growth, storage, lookup, and instrumentation policies cooperate via C++ concepts (`include/slotmap/Concepts.hpp`)
- **Overlay Packages**: Policy helpers via vcpkg overlays (`qlibs`, `stdx`, `cib`, `boost-ext`)
- **No RTTI/Exceptions**: All error handling through `std::expected` with policy-specific error enums

## Build System

**CMake Presets** (all builds must use presets):
```bash
# Configure
cmake --preset clang-debug          # Debug build with warnings as errors
cmake --preset clang-release        # Release build

# Build
cmake --build --preset clang-debug
cmake --build --preset clang-release

# Test
ctest --preset clang-debug

# Documentation (MRDocs + Doxygen + Mermaid)
cmake --build --preset clang-debug --target docs
# Output: build/clang-debug/docs/
```

**Toolchain Requirements:**
- clang-21 and clang++-21 (via Ubuntu Toolchain PPA)
- mold linker
- cmake 3.28+
- ninja
- vcpkg (dependencies managed via `vcpkg.json` and overlays in `vcpkg-overlays/`)

## Development Workflow

**Standard Development Cycle:**
1. Work in devcontainer (`.devcontainer/`) on Ubuntu 24.04 host
2. Make code changes
3. Run `scripts/pre_commit.sh` locally and fix all failures
4. Commit and push
5. Trigger remote GitHub Actions lint/validation
6. Poll GH Actions every 5 seconds; if failure or >5 min, stop and report
7. Only after validation passes, proceed with remote rebuild scripts

**Policy-First Approach:**
- All behavior changes go through policies (growth, storage, lookup, instrumentation)
- Shared helpers belong under `include/slotmap/` or overlay packages
- When changing policies, update:
  - `docs/Architecture/` and `docs/Policies/`
  - Reference docs via `scripts/generate_docs.sh`
  - Diagrams in `docs/Diagrams/`

## Code Style Requirements

**Template Metaprogramming:**
- Eliminate code duplication using templates, not copy-paste
- Use `bool` template parameters for const/non-const variants
- Provide type aliases for clean APIs (e.g., `using my_iterator = my_iterator_impl<false>`)
- Follow standard library patterns: `std::conditional_t`, SFINAE

**Control Flow:**
- Prefer early exits with guard clauses
- Minimize nesting depth
- Handle edge cases first, then return
- Main logic should flow top-to-bottom without deep nesting

**Comments:**
- Use `/* */` for multi-line blocks (not Doxygen `/** */`)
- Use `**bold**` for headings in comments
- Write natural, conversational explanations
- Focus on design rationale and "why", not "what"
- Explain assertions directly above them
- Only comment non-obvious code, performance implications, constraints

**Example Comment Style:**
```cpp
/*

**Intrusive doubly-linked list**

This is a circular intrusive doubly-linked list using a sentinel node.

The sentinel acts as both head and tail, allowing for uniform insert/remove
operations without special cases or null checks.

This design avoids dynamic memory allocation and provides O(1) insertion and removal.

*/
```

## Architecture Deep Dive

**Policy Coordination:**
- Policies communicate through C++ concepts defined in `include/slotmap/Concepts.hpp`
- No direct coupling between policies; all interactions via concept requirements
- Service wiring (allocators, monitoring) through Intel CIB pattern, not global state

**Error Handling Philosophy:**
- Zero exceptions; all APIs return `std::expected<T, ErrorEnum>` or `boost::outcome::result<T>`
- Each policy defines its own error enums
- Error propagation uses monadic operations (`and_then`, `or_else`)

**SIMD Integration:**
- Google Highway provides cross-platform SIMD primitives
- Policies opt-in to SIMD acceleration for scans/compaction
- Fallback implementations for non-SIMD builds

## Testing

- Unit tests in `tests/` directory
- Tests must align with policy APIs
- Run via CMake preset: `ctest --preset clang-debug`
- Test output on failure is enabled by default

## Dependencies

**Never add dependencies outside vcpkg system:**
- Declare in `vcpkg.json`
- Custom/overlay ports go in `vcpkg-overlays/`
- No git submodules or manual downloads

## Remote Development

**Remote Devcontainer Workflow:**
```bash
# From laptop, deploy to remote host
./scripts/deploy_remote_devcontainer.sh

# Connect to remote devcontainer
ssh -i ~/.ssh/id_ed25519 -p 9222 <remote-username>@c24s1.ch2
```

See `docs/remote-devcontainer.md` for troubleshooting and cleanup commands.

## Validation Rules (AI_OPS Compliance)

1. **Language**: C++23 (C++26 experiments behind concepts), clang-21, mold
2. **No Exceptions/RTTI**: Use `std::expected`/`boost::outcome::result`
3. **Policies First**: All behavior changes through policy system
4. **Documentation**: Update markdown specs, reference docs, and diagrams together
5. **Testing**: Keep unit tests aligned with policy APIs
6. **Dependencies**: vcpkg only, no ad-hoc submodules
7. **Validation Cadence**:
   - Run `scripts/pre_commit.sh` locally first
   - Wait for GH Actions to pass (poll every 5s, fail if >5 min)
   - No skipping local checks
   - Stop on any failure
8. **Container Assembly**: Prefer Dev Container features over Dockerfile bloat

## Key Documentation

- `docs/Architecture/Overview.md` - Core architecture principles
- `docs/Policies/*.md` - Individual policy documentation
- `docs/remote-devcontainer.md` - Remote development setup
- `docs/devcontainer-tools.md` - Tooling inventory
- `.cursor/rules/coding_style.mdc` - Detailed coding conventions
- `.cursor/rules/comment_style.mdc` - Comment formatting rules
