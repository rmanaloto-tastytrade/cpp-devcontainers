## Key Recommendations

1. **Use Official Docker Actions:** Stick to `docker/bake-action@v5`, `docker/metadata-action@v5`, `docker/login-action@v3`, `docker/setup-buildx-action@v3`

2. **Two-Stage Base Build:** Always build base images locally first (`load: true`) to avoid docker.io pulls, then build final images referencing local bases

3. **GHA Cache Over Local:** Use `type=gha` caching for CI; reserve local cache for local testing only

4. **Matrix Isolation:** Each variant gets its own cache scope and artifact namespace

5. **Fail-Fast Off:** Let all matrix jobs complete for comprehensive CI feedback

6. **Always Cleanup:** Self-hosted runners need aggressive cleanup after every run

7. **Metadata Action for Tags:** Never manually construct tags; use `docker/metadata-action` outputs

8. **Provenance/SBOM:** Enable for supply chain compliance

9. **Timestamped Artifacts:** Use `YYYYMMDDHHMMSS.nnnnnnnnn` format for all logs

10. **Monitor Resources:** Log disk usage in cleanup job to catch space issues early

This plan provides a production-ready, maintainable workflow that leverages official Docker GitHub Actions while respecting self-hosted runner constraints.
