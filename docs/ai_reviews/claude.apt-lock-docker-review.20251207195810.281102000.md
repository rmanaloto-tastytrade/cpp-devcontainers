## Devcontainer Docker Setup Review

**Apt Cache Locking Analysis**

### ✅ Already Locked (Lines with `sharing=locked`)
- L87-130: Core OS packages (gcc, git, cmake installs)
- L133-140: Linux perf tools
- L143-158: Ubuntu toolchain PPA (gcc versions)
- L160-167: Git PPA
- L170-177: Kitware CMake repo

### ❌ Missing Locks - CRITICAL

**Base Stage (lines 223-260):**
- L238-259: LLVM/Clang install from apt.llvm.org - **NO LOCKS**
  - High-risk: Multiple parallel builders could corrupt cache
  - Fix: Add `--mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt/lists,sharing=locked`

**Devcontainer Stage (lines 643-680):**
- L658-678: LLVM/Clang install (duplicate logic from base) - **NO LOCKS**
  - Same risk as above
  - Fix: Add locked cache mounts

**Valgrind Stage (lines 464-465):**
- L465: Fallback `apt-get install valgrind` - **NO LOCKS**
  - If source download fails, apt fallback has no protection
  - Fix: Add locked cache mounts

### 🔧 Optimization Opportunities

**Serialization Not Required:**
- Base stage has sequential RUNs (L87, L133, L143, L160, L170) that all use `sharing=locked`
- Already safe for parallel execution due to BuildKit's dependency graph
- No additional serialization needed

**Cache Efficiency:**
- All locked RUNs properly clean with `rm -rf /var/lib/apt/lists/*`
- Good: Prevents stale metadata in cache layers

### 📋 Action Items

1. **Add locks to L238-259 (base stage LLVM install)**
2. **Add locks to L658-678 (devcontainer stage LLVM install)**
3. **Add locks to L465 (valgrind fallback)**
4. **Consider**: Extract LLVM install logic to shared function to avoid duplication (DRY violation at lines 223-260 vs 643-680)

### 🎯 Risk Assessment
- **High**: Unprotected LLVM installs could cause corrupted caches in parallel builds
- **Medium**: Valgrind fallback rarely triggers but should be consistent
- **Low**: Other stages already properly protected
