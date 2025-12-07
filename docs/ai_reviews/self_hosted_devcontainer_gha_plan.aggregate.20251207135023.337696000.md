# Aggregate: GHCR-only fallback review (2025-12-07)

Sources: codex, claude, gemini, cursor-agent (latest round).

Findings:
- Remaining risk: buildx/buildkit may still pull docker.io frontend/worker images unless pinned; cache refs could contain docker.io; guard only greps bake print.
- Base fallback: GHCR cache-from set; no explicit pull from GHCR if local base missing; workflow doesn’t set buildkit policy to deny docker.io.

Suggested fixes:
- Pin frontend/daemon images away from docker.io (set BUILDKITD_IMAGE/DOCKER_BUILDKIT_IMAGE or pre-pull GHCR mirrors), or use local frontend.
- Add BuildKit source policy to block docker.io (BUILDKIT_CONFIG with source-policy deny docker.io).
- Add explicit GHCR pull/cache-from step for base image when available; keep pull:false during bake to avoid docker.io.
- Strengthen guard: grep bake print and cache refs for docker.io, fail fast; consider CI smoke bake with no BASE_IMAGE to ensure fail.
