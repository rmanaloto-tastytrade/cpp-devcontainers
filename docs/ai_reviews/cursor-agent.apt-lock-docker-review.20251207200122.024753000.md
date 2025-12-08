
## Review Summary: Devcontainer Docker Setup

### Missing apt cache locks (3 locations)

1. Lines 223-260: Base stage LLVM/Clang install
   - Missing: `--mount=type=cache,target=/var/cache/apt,sharing=locked` and `--mount=type=cache,target=/var/lib/apt/lists,sharing=locked`
   - Fix: Add both cache mounts to the RUN command

2. Line 465: Valgrind fallback apt install
   - Missing: apt cache mounts (RUN already has `/tmp/valgrind-build` mount)
   - Fix: Add apt cache mounts to existing RUN command

3. Lines 643-680: Devcontainer stage LLVM/Clang install
   - Missing: Same apt cache mounts
   - Fix: Add both cache mounts to the RUN command

### Other issues

- Line 465: Uses `&&` chaining instead of separate commands with `set -eux` pattern
  - Current: `apt-get update && apt-get install ... && rm -rf ...`
  - Better: Separate commands (already using `set -eux`)

### Consistency notes

- All other apt install blocks (lines 87, 133, 143, 161, 170) correctly use `sharing=locked`
- Pattern is consistent: both `/var/cache/apt` and `/var/lib/apt/lists` mounts

### Recommended fixes

```dockerfile
# Fix 1: Line 223 - Add cache mounts before "set -e;"
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
  set -e; \

# Fix 2: Line 452 - Add apt cache mounts to existing RUN
RUN --mount=type=cache,target=/tmp/valgrind-build \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
  set -eux; \

# Fix 3: Line 465 - Split && chain (within existing set -eux)
apt-get update; \
apt-get install -y --no-install-recommends valgrind; \
rm -rf /var/lib/apt/lists/*; \

# Fix 4: Line 643 - Add cache mounts before "set -e;"
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
  set -e; \
```

All apt operations will then use locked cache mounts, preventing concurrent build conflicts.
