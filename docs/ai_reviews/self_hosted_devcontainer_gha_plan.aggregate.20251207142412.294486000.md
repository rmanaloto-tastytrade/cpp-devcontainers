# Aggregate: GHCR-only guard review (latest)

Sources: codex, claude, gemini, cursor-agent (latest round).

Findings / residual risks:
- Guard gap: current workflow only greps base target; does not assert BASE_IMAGE_TAG/BASE_CACHE_TAG are GHCR-qualified; does not check permutation bake plan. Guard regex may miss docker.io variants.
- BuildKit/frontend pulls: Dockerfile syntax line `docker/dockerfile:1.7` and buildx builder image default `moby/buildkit:buildx-stable-1` still come from docker.io if not cached.
- Policy: no BuildKit source-policy to deny docker.io.
- (Minor) CI script may use unqualified base tag if pulling were enabled.

Suggested fixes:
1) Workflow guard: fail if BASE_IMAGE_TAG/BASE_CACHE_TAG contain docker.io or are not ghcr.io/*; also `bake --print ${{ steps.map.outputs.target }}` and grep for docker.io and expected BASE_IMAGE.
2) Pin frontend/builder: use `# syntax=ghcr.io/docker/dockerfile:1.7` and set buildx `driver-opts: image=ghcr.io/moby/buildkit:buildx-stable-1` (or your GHCR mirror/pre-pull).
3) Optional hardening: set `BUILDKIT_CONFIG` with source-policy denying docker.io.
