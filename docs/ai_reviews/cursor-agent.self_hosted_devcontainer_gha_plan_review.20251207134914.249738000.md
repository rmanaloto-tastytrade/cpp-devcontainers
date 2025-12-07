
## Review summary

### What's already correct
1. Base tag is GHCR FQIN: `docker-bake.hcl` sets `BASE_TAG` to `ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/cpp-dev-base:local`
2. `BASE_IMAGE` arg uses GHCR: All targets inherit from `_base` which sets `BASE_IMAGE = "${BASE_TAG}"`
3. Dockerfile default is GHCR: Default `ARG BASE_IMAGE=ghcr.io/...`
4. `pull: false` is set: Both base and devcontainer builds use `pull: false`
5. GHCR cache-from/to: Registry cache refs use GHCR
6. Guard step exists: Checks bake print for docker.io

### Remaining gaps (low–medium risk)

1. Guard only checks base target — doesn't validate permutation targets
2. No env var validation — `BASE_IMAGE_TAG` and `BASE_CACHE_TAG` aren't validated as GHCR-qualified
3. Guard regex could be more comprehensive — may miss some docker.io patterns
4. No verification that `BASE_IMAGE` is set in permutation targets

### Answer to your questions

Q: Any remaining docker.io pull risk?
A: Very low. The main risks are:
- Accidental env var changes (mitigated by validation)
- Permutation target misconfiguration (mitigated by validation)
- BuildKit ignoring `pull: false` (unlikely, but validation catches it)

Q: Missing GHCR fallback for base?
A: Not applicable. Base is built locally with `pull: false`, so no pull occurs. The GHCR FQIN ensures that if BuildKit attempted a pull, it would go to GHCR, not docker.io.

### Recommended fixes

Created two documents:
1. `docs/ai_reviews/ghcr-only-review.20251207.md` — Detailed analysis
2. `docs/ai_reviews/ghcr-only-fixes-to-apply.md` — Exact code changes needed

The fixes add:
- Env var validation steps (prevent regressions)
- Enhanced guard for base target (better regex, explicit BASE_IMAGE)
- Guard for permutation targets (validates all targets)
- Verification that BASE_IMAGE is set correctly

Should I apply these fixes to the workflow file, or do you prefer to review and apply them manually?
