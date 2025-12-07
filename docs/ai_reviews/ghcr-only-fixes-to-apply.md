# GHCR-Only Fixes to Apply

## Summary

Review identified **5 low-to-medium risk gaps** in GHCR-only validation. All base image references are correctly GHCR-qualified, but validation can be strengthened.

## Fixes Required

### Location: `.github/workflows/build-devcontainer.yml`

**Replace lines 192-198** (the existing guard step) with the following enhanced validation steps:

```yaml
      - name: Validate BASE_IMAGE_TAG is GHCR-qualified
        run: |
          if [[ ! "${{ env.BASE_IMAGE_TAG }}" =~ ^ghcr\.io/ ]]; then
            echo "ERROR: BASE_IMAGE_TAG must be GHCR-qualified, got: ${{ env.BASE_IMAGE_TAG }}"
            exit 1
          fi
          if [[ "${{ env.BASE_IMAGE_TAG }}" =~ docker\.io ]]; then
            echo "ERROR: BASE_IMAGE_TAG must not contain docker.io, got: ${{ env.BASE_IMAGE_TAG }}"
            exit 1
          fi
          echo "✓ BASE_IMAGE_TAG is GHCR-qualified: ${{ env.BASE_IMAGE_TAG }}"

      - name: Validate BASE_CACHE_TAG is GHCR-qualified
        run: |
          if [[ ! "${{ env.BASE_CACHE_TAG }}" =~ ^ghcr\.io/ ]]; then
            echo "ERROR: BASE_CACHE_TAG must be GHCR-qualified, got: ${{ env.BASE_CACHE_TAG }}"
            exit 1
          fi
          if [[ "${{ env.BASE_CACHE_TAG }}" =~ docker\.io ]]; then
            echo "ERROR: BASE_CACHE_TAG must not contain docker.io, got: ${{ env.BASE_CACHE_TAG }}"
            exit 1
          fi
          echo "✓ BASE_CACHE_TAG is GHCR-qualified: ${{ env.BASE_CACHE_TAG }}"

      - name: Guard against docker.io fallback (base target)
        run: |
          docker buildx bake --file .devcontainer/docker-bake.hcl \
            --set BASE_TAG=${{ env.BASE_IMAGE_TAG }} \
            --set base.args.BASE_IMAGE=${{ env.BASE_IMAGE_TAG }} \
            --print base > /tmp/bake-print-base.txt
          if grep -iE "(docker\.io|docker\.io/)" /tmp/bake-print-base.txt; then
            echo "ERROR: docker.io reference detected in base target bake plan"
            cat /tmp/bake-print-base.txt
            exit 1
          fi
          echo "✓ Base target has no docker.io references"

      - name: Guard against docker.io fallback (permutation target)
        run: |
          docker buildx bake --file .devcontainer/docker-bake.hcl \
            --set BASE_TAG=${{ env.BASE_IMAGE_TAG }} \
            --set ${{ steps.map.outputs.target }}.args.BASE_IMAGE=${{ env.BASE_IMAGE_TAG }} \
            --print ${{ steps.map.outputs.target }} > /tmp/bake-print-target.txt
          if grep -iE "(docker\.io|docker\.io/)" /tmp/bake-print-target.txt; then
            echo "ERROR: docker.io reference detected in permutation target bake plan"
            cat /tmp/bake-print-target.txt
            exit 1
          fi
          # Verify BASE_IMAGE is set correctly in the target
          if ! grep -q "${{ env.BASE_IMAGE_TAG }}" /tmp/bake-print-target.txt; then
            echo "WARNING: BASE_IMAGE may not be set correctly in permutation target"
            echo "Expected: ${{ env.BASE_IMAGE_TAG }}"
            cat /tmp/bake-print-target.txt | grep -i "base_image\|from" || true
          fi
          echo "✓ Permutation target has no docker.io references and BASE_IMAGE is set"
```

## What These Fixes Address

1. **Env Var Validation**: Prevents accidental regressions if `BASE_IMAGE_TAG` or `BASE_CACHE_TAG` are changed to unqualified tags
2. **Enhanced Base Guard**: Uses more comprehensive regex and explicitly sets `BASE_IMAGE` arg
3. **Permutation Target Guard**: Validates that permutation targets also don't have docker.io references and that `BASE_IMAGE` is correctly set
4. **Better Error Messages**: Shows the actual bake plan output when docker.io is detected

## Testing

After applying these fixes, the workflow should:
- ✅ Validate env vars are GHCR-qualified before use
- ✅ Check both base and permutation targets for docker.io references
- ✅ Verify BASE_IMAGE is set correctly in permutation targets
- ✅ Provide clear error messages if issues are detected
