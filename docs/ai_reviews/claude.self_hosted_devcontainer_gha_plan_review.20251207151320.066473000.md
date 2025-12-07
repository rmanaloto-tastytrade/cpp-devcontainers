## Analysis

**Current Setup:**
- Matrix builds 6 permutations (gcc14/15 × clang21/22/p2996) sequentially via GHA matrix strategy
- Each job builds `base` locally first (load-only, cached), then specific devcontainer variant
- Manual permutation→target mapping via case statement
- GHCR-only enforcement with pre-build validation guards

**Issues:**
1. **Redundant base builds** - Base rebuilt 6 times despite shared dependency
2. **Manual mapping overhead** - Case statement for permutation→target translation
3. **No parallelism** - Base builds can't parallelize across jobs
4. **Verbose validation** - Repeated GHCR guards in every job

## Recommendations

### Option 1: Single Multi-Target Bake (Recommended)
```yaml
# Simplified workflow - single bake call with group target
- name: Build all devcontainers
  uses: docker/bake-action@v6
  with:
    files: .devcontainer/docker-bake.hcl
    targets: matrix  # Uses existing group "matrix"
    push: ${{ github.event_name == 'push' }}
    load: true
    set: |
      BASE_TAG=${{ env.BASE_IMAGE_TAG }}
      BASE_CACHE_TAG=${{ env.BASE_CACHE_TAG }}
```

**Benefits:**
- Bake orchestrates base→variant dependencies automatically
- Single validation, single hadolint run
- Better layer caching across variants
- Eliminate manual mapping logic

**Trade-offs:**
- All-or-nothing builds (no partial matrix success)
- Harder to identify which permutation failed
- Longer single job vs parallel short jobs

### Option 2: Dedicated Base Job + Matrix (Current Best)
Keep current approach but optimize:
```yaml
jobs:
  build-base:
    steps:
      - name: Build & push base once
        uses: docker/bake-action@v6
        with:
          targets: base
          push: true  # Push to GHCR for reuse
          
  build-variants:
    needs: build-base
    strategy:
      matrix:
        target: [devcontainer_gcc14_clang_qual, ...]  # Direct targets
    steps:
      - uses: docker/bake-action@v6
        with:
          targets: ${{ matrix.target }}
          pull: true  # Pull shared base from GHCR
```

**Benefits:**
- Base built once, pulled by all variants
- Maintains parallel matrix execution
- Clear separation of concerns
- No manual mapping

### Option 3: Reusable Workflow
GitHub's `workflow_call` pattern for common steps:
```yaml
# .github/workflows/build-devcontainer-variant.yml
on:
  workflow_call:
    inputs:
      target: { type: string, required: true }
      
jobs:
  build:
    steps:
      - uses: docker/bake-action@v6
        with:
          targets: ${{ inputs.target }}
```

**Benefits:**
- DRY validation/hadolint logic
- Easier testing of individual permutations
- Better for incremental changes

**Trade-offs:**
- More workflow files to maintain

## Quick Win Actions

1. **Eliminate mapping** - Use `matrix.target` directly with bake target names
2. **Shared base job** - Build base once, push to GHCR, pull in variants  
3. **Single validation** - Move GHCR guards to dedicated job or use `docker/bake-action` built-in checks
4. **Group targets** - Leverage existing `group "matrix"` for bulk operations

**Recommended Path:** Option 2 (dedicated base job) maintains your parallel strategy while eliminating redundant base builds. Option 1 is simpler but loses granular failure visibility.
