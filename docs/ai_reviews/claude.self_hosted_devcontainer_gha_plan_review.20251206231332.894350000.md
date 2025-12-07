## Self-Hosted Devcontainer Build Review (linux/amd64)

### ✅ Strengths (Working as Designed)

**Runner Safety**:
- Workflow correctly gates on `c0802s4-000` runner via labels + explicit name guard
- PR fork protection via `github.event.pull_request.head.repo.full_name` check
- 120m timeout on both build and publish jobs prevents runaway costs

**Build Validation Flow**:
- `validate` stage in Dockerfile (lines 704-754) performs comprehensive checks: compiler sanity, tool versions, path/symlink validation
- CI script runs `validate_*` targets before actual build (build_devcontainers_ci.sh:104-108)
- Preflight checks: hadolint, devcontainer schema validation, bake file validation

**Caching & Tagging**:
- GHA cache mode with per-permutation scope
- Tag strategy: `{perm}`, `{sha}-{perm}`, optional `latest-{perm}` (disabled by default via `PUBLISH_LATEST=0`)
- GHCR push gated to `main` branch only

---

### ⚠️ Remaining Gaps & Risks

#### 1. **Validation Stage Not Blocking Push in Workflow**
**Risk**: Validation targets run with `--no-cache` (line 106) but actual build may use stale cache layers, bypassing validation failures.

**Action**: Ensure validation failures halt workflow **before** push. Current structure runs validate → build → push sequentially, but if validate passes with `--no-cache` and build uses cache, layer drift could occur.

**Fix**: Add explicit check that validate target completed successfully before proceeding to build step.

---

#### 2. **SBOM & Trivy Scan Run AFTER Push**
**Risk**: Vulnerable images already published to GHCR before scan results available (lines 103-123).

**Action**: Move SBOM/Trivy steps **before** push to prevent vulnerable images from reaching registry. Current flow:
```
build → push → SBOM → Trivy (blocking)
```
Should be:
```
build → SBOM → Trivy (blocking) → push
```

---

#### 3. **Separate Publish Job Re-Builds Instead of Re-Tagging**
**Risk**: `publish` job (lines 124-200) rebuilds images instead of promoting validated artifacts from `build` job. This wastes compute and introduces inconsistency risk.

**Action**: 
- `build` job: build, validate, scan, store artifacts (images + tags)
- `publish` job: pull from cache/registry, re-tag, push (no rebuild)

---

#### 4. **No Digest Pinning for Base Images**
**Risk**: Dockerfile uses `ubuntu:24.04` without digest pinning (implicit in HCL), exposing supply chain tampering risk.

**Action**: Pin base images by digest in Dockerfile or HCL variables (e.g., `ubuntu@sha256:abc123...`). Document rotation policy.

---

#### 5. **Cache Poisoning Prevention Missing**
**Risk**: GHA cache mode (`type=gha`) doesn't isolate PR caches from main branch, allowing malicious PR to poison shared cache.

**Action**: Scope caches by ref/branch:
```hcl
cache-from=type=gha,scope=${target}-${GITHUB_REF_NAME}
```

---

#### 6. **Deferred Security Items (Plan Line 45-48)**
**Incomplete**:
- ❌ Provenance/attestation (SLSA signatures)
- ❌ Secrets handling docs (GITHUB_TOKEN rotation, GHCR PAT best practices)
- ⚠️ Vulnerability scan present but not comprehensive (only CRITICAL/HIGH, no OS package audit)

**Action**: 
- Add `docker buildx build --provenance=true --sbom=true` flags
- Document GITHUB_TOKEN scope requirements and rotation policy in `.github/workflows/README.md`
- Extend Trivy to include `--scanners vuln,secret,config`

---

#### 7. **No Rollback Procedure Documented**
**Risk**: If bad image pushed to `main`, no documented process to revert GHCR tags or rebuild from known-good SHA.

**Action**: Add rollback section to `.github/workflows/README.md`:
- How to re-tag previous SHA as latest
- How to trigger rebuild from specific commit
- GHCR retention policy (currently unbounded)

---

#### 8. **Workflow Concurrency May Block Urgent Fixes**
**Risk**: `cancel-in-progress: false` (line 20) means long-running main branch builds block subsequent commits for up to 120m.

**Action**: Consider `cancel-in-progress: true` for non-main branches while keeping false for main (where cache consistency matters).

---

### 🔧 Quick Wins (Priority Order)

1. **Move Trivy before push** (lines 114-123 → before line 82) - prevents vulnerable images escaping
2. **Refactor publish job** to re-tag instead of rebuild - saves ~40-60m per run
3. **Pin base image digests** - mitigates supply chain risk
4. **Scope GHA cache by branch** - prevents PR cache poisoning
5. **Document rollback procedure** - operational readiness

---

### 📊 Risk Summary

| Category | Current State | Risk Level | Effort to Fix |
|----------|--------------|-----------|---------------|
| Validate stage | ✅ Implemented | Low | Done |
| Security scan timing | ⚠️ Post-push | **High** | 30m (move steps) |
| Publish duplication | ⚠️ Rebuilds | Medium | 2h (refactor job) |
| Base image pinning | ❌ Missing | Medium | 1h (add digests) |
| Cache isolation | ❌ Missing | Medium | 30m (scope by ref) |
| Provenance/attestation | ❌ Deferred | Medium | 3h (implement) |
| Rollback docs | ❌ Missing | Low | 1h (write guide) |

**Total estimated effort to close all gaps**: ~8-10 hours
