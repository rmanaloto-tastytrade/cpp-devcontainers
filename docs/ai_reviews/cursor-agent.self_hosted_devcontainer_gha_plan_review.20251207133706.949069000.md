
The edit tool is having issues. Summary of fixes:

## Fix Summary: Prevent docker.io Fallback

**Root cause:** Unqualified tag `cpp-dev-base:local` in `docker-bake.hcl` causes BuildKit to fall back to `docker.io/library/`.

### Required Changes:

1. **`.devcontainer/docker-bake.hcl` (lines 127-132):**
   - Remove `"cpp-dev-base:local"` tag
   - Change `"localhost/cpp-dev-base:local"` to `"localhost/${BASE_TAG}"`
   - Update comment to note fully qualified alias

2. **`.github/workflows/build-devcontainer.yml`:**
   - Add step to set `BASE_TAG` env var before building base
   - Add validation step to fail if docker.io appears
   - Add `set:` with `BASE_IMAGE` arg to both bake steps
   - Add `pull: false` to prevent BuildKit pulls

3. **Validation:** Add check that fails if bake manifest contains `docker.io`

Created `FIX_DOCKERIO_FALLBACK.md` with exact code changes. The key points:
- Use `${BASE_TAG}` (GHCR-qualified) everywhere
- Set `BASE_IMAGE` arg in all bake targets
- Use `pull: false` to prevent pulls
- Validate no docker.io references

Should I try a different approach to apply these changes, or will you apply them from the document?
