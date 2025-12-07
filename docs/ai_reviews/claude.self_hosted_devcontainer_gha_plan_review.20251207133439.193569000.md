# Fix: Prevent docker.io Fallback & Use Local/GHCR Base

## Root Cause
BuildKit defaults to `docker.io/library/` for unqualified image references like `cpp-cpp-dev-base:local`.

## Actionable Fixes

### 1. **Qualify Base Image Reference**
```dockerfile
# .devcontainer/Dockerfile
-FROM cpp-cpp-dev-base:local
+FROM ghcr.io/rmanaloto-tastytrade/cpp-cpp-dev-base:local
```
Or use build arg:
```dockerfile
ARG BASE_IMAGE=ghcr.io/rmanaloto-tastytrade/cpp-cpp-dev-base:local
FROM ${BASE_IMAGE}
```

### 2. **Bake HCL: Explicit Context & Args**
```hcl
# .devcontainer/docker-bake.hcl
target "cpp-dev" {
  context = "."
  dockerfile = "Dockerfile"
  args = {
    BASE_IMAGE = "ghcr.io/rmanaloto-tastytrade/cpp-cpp-dev-base:local"
  }
  cache-from = ["type=registry,ref=ghcr.io/rmanaloto-tastytrade/cpp-cpp-dev-cache"]
}
```

### 3. **Workflow: Build Base First, Tag for Reuse**
```yaml
# .github/workflows/build.yml
- name: Build base image
  run: |
    docker build -t ghcr.io/rmanaloto-tastytrade/cpp-cpp-dev-base:local -f .devcontainer/Dockerfile.base .
    docker tag ghcr.io/rmanaloto-tastytrade/cpp-cpp-dev-base:local cpp-cpp-dev-base:local

- name: Bake with local base
  run: docker buildx bake --set *.cache-from=type=local,src=/tmp/.buildx-cache
```

### 4. **Validation Guards**
```yaml
- name: Verify no docker.io pulls
  run: |
    docker buildx bake --print | grep -i 'docker.io' && exit 1 || true
```

### 5. **Cache Strategy**
```yaml
- uses: actions/cache@v4
  with:
    path: /tmp/.buildx-cache
    key: buildx-${{ runner.os }}-${{ hashFiles('.devcontainer/**') }}
```

## Summary
- **Always use GHCR-qualified base tags** (`ghcr.io/owner/repo:tag`)
- **Build base in workflow**, tag as both GHCR and local alias
- **Bake uses local tags** but DockerHub is never attempted
- **Validation step** catches any `docker.io` references pre-push
