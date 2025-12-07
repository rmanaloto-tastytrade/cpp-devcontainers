Remaining docker.io touchpoints / guard gaps:

- `.github/workflows/build-devcontainer.yml:192-200` – guard greps only the `base` bake print. It doesn’t assert `BASE_IMAGE_TAG`/`BASE_CACHE_TAG` are GHCR-qualified nor check the permutation target plan. If someone feeds an unqualified base tag or a docker.io cache ref, the guard passes. Fix: add a quick env check (`[[ $BASE_IMAGE_TAG == ghcr.io/* ]] && ! grep -i docker.io <<<"$BASE_IMAGE_TAG"` etc.) and run a second `bake --print ${{ steps.map.outputs.target }}` grep to ensure the permutation plan has no docker.io and the rendered `BASE_IMAGE` matches the GHCR FQIN.

- `.devcontainer/Dockerfile:1` – `# syntax=docker/dockerfile:1.7` pulls the Dockerfile frontend from docker.io. Fix: pin to the GHCR mirror (`# syntax=ghcr.io/docker/dockerfile:1.7`) or vendor the frontend (`syntax=local`).

- `.github/workflows/build-devcontainer.yml:169-176` – `docker/setup-buildx-action` defaults to the docker.io `moby/buildkit:buildx-stable-1` image. If it isn’t cached locally, the runner will hit docker.io before your guard runs. Fix: set `driver-opts: image=ghcr.io/moby/buildkit:buildx-stable-1` (or your own GHCR-hosted buildkit image) in the Buildx setup step.

- Optional hardening: add a BuildKit `source-policy` to deny docker.io and point `BUILDKIT_CONFIG` at it, so any fallback attempt fails even if a new tag slips through.