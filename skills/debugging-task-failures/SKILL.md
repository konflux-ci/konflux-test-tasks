---
name: debugging-task-failures
description: Use when a scan task fails in a pipeline, when task results have unexpected values, when understanding scan output formats, or when debugging bundle build failures.
---

# Debugging Task Failures

## Overview

Debugging Tekton task failures in pipelines requires understanding task result formats, runner images, and common failure patterns. These scanning tasks (clair-scan, clamav-scan, deprecated-image-check, roxctl-scan, tpa-scan) share common patterns and error modes.

## When to Use

- A scan task fails in a Konflux pipeline
- Task results have unexpected structure or values
- Understanding what each result field means
- Debugging bundle build failures
- Reading scan reports attached to images as OCI artifacts

## Task Result Formats

All scanning tasks must produce standardized result formats.

### TEST_OUTPUT (all tasks)

JSON object with scan result status:

```json
{
  "result": "SUCCESS|WARNING|ERROR|SKIPPED",
  "note": "Human-readable description of result",
  "timestamp": "ISO-8601 timestamp (e.g., 2025-05-20T14:30:00Z)"
}
```

**Result values:**

- `SUCCESS` — scan passed, no issues found
- `WARNING` — scan completed with non-critical issues
- `ERROR` — scan failed or found critical issues
- `SKIPPED` — scan was skipped (image not relevant, etc.)

### SCAN_OUTPUT (vulnerability tasks only)

JSON object with vulnerability counts by severity:

```json
{
  "vulnerabilities": {
    "critical": 0,
    "high": 2,
    "medium": 5,
    "low": 12,
    "unknown": 1
  },
  "unpatched_vulnerabilities": {
    "critical": 0,
    "high": 0,
    "medium": 1,
    "low": 5,
    "unknown": 0
  }
}
```

- `vulnerabilities` — Total count by severity from scan database
- `unpatched_vulnerabilities` — Vulnerabilities without available patches

### IMAGES_PROCESSED

JSON object mapping image pull specifications to their digests:

```json
{
  "image": {
    "pullspec": "quay.io/org/image:tag",
    "digests": ["sha256:abc123...", "sha256:def456..."]
  }
}
```

Multiple digests if image built for multiple architectures.

### REPORTS

JSON object mapping image digests to OCI artifact report digests:

```json
{
  "sha256:abc123...": {
    "scan_report": "sha256:report-digest-1...",
    "compliance_report": "sha256:report-digest-2..."
  }
}
```

Reports are stored as OCI artifacts in the image registry.

## Common Task Step Failures

### clair-scan (Vulnerability Scanning)

| Step | Failure | Cause | Fix |
|------|---------|-------|-----|
| `get-image-manifests` | "unauthorized" | Missing docker auth or expired token | Check secret/credentials are mounted |
| `get-image-manifests` | "not found" | Image does not exist in registry | Verify image pull spec is correct |
| `get-vulnerabilities` | OOM killed | Image has too many layers; too much memory | Increase `computeResources.limits.memory` |
| `oci-attach-report` | "failed to push" | Registry auth issue or storage quota exceeded | Check registry credentials and quota |
| `conftest-vulnerabilities` | Policy violation | Vulnerability severity exceeds threshold | Review Conforma policies in `policies/` |

### clamav-scan (Antivirus Scanning)

Similar to clair-scan but uses ClamAV malware database instead of vulnerability DB.

| Step | Failure | Cause | Fix |
|------|---------|-------|-----|
| `clamscan-image` | "database outdated" | ClamAV DB not current | Update clamav-db image in task |
| `clamscan-image` | Timeout | Large image with many files | Increase timeout or exclude paths |

### deprecated-image-check (Base Image Deprecation)

| Step | Failure | Cause | Fix |
|------|---------|-------|-----|
| `get-image-data` | "service unavailable" | Pyxis API down (Red Hat's image metadata service) | Retry later; not a task issue |
| `conftest-deprecated` | Policy failure | Base image marked as deprecated | Update to newer base image |

### roxctl-scan (Red Hat ACS)

| Step | Failure | Cause | Fix |
|------|---------|-------|-----|
| `roxctl-image-scan` | "connection refused" | ROX_CENTRAL_ADDR unreachable | Verify ACS cluster URL and network access |
| `roxctl-image-scan` | "authentication failed" | ROX_API_TOKEN invalid or expired | Regenerate API token in ACS |

### tpa-scan (Trusted Profile Analyzer)

| Step | Failure | Cause | Fix |
|------|---------|-------|-----|
| `tpa-scan` | "timeout" | TPA service slow or unresponsive | Retry; may be service issue |

## Runner Images

All scanning tasks use utility images from Konflux:

| Image | Purpose | Source |
|-------|---------|--------|
| `quay.io/konflux-ci/konflux-test` | General utility functions, conftest policy execution | github.com/konflux-ci/konflux-test |
| `quay.io/konflux-ci/task-runner` | OCI artifact attachment via oras | github.com/konflux-ci/task-runner |
| `quay.io/konflux-ci/clair-in-ci:latest` | Clair vulnerability database | github.com/konflux-ci/clair-in-ci-db |
| `quay.io/konflux-ci/clamav-db:latest` | ClamAV antivirus database | github.com/konflux-ci/konflux-clamav |

**Pinning:** Most tasks use floating `latest` tags. For reproducibility, pin to specific digest: `image@sha256:...`

## Environment Variable Pattern

Never use Tekton parameters directly in scripts. Always pass through env vars first.

**WRONG (security risk):**

```yaml
spec:
  steps:
    - name: scan
      script: |
        scan-tool "$(params.image-url)"  # Code injection vulnerability
```

**CORRECT:**

```yaml
spec:
  steps:
    - name: scan
      env:
        - name: IMAGE_URL
          value: "$(params.image-url)"
      script: |
        scan-tool "$IMAGE_URL"  # Safe
```

## Retry Logic

Most scan tasks use `RETRY_COUNT` (default: 5) for transient failures (timeouts, rate limits).

Set via `stepTemplate` env variable:

```yaml
spec:
  stepTemplate:
    env:
      - name: RETRY_COUNT
        value: "3"
```

## Debugging Bundle Builds

Each task version has build pipelines in `.tekton/`:

**Pull request:** `.tekton/<task>-<ver>-pull-request.yaml`  
**Push:** `.tekton/<task>-<ver>-push.yaml`

**Debug steps:**

1. Find the PipelineRun in Pipelines-as-Code logs
2. Check step status and logs in Konflux UI
3. Look for:
   - Build failures (container build failed)
   - Security scan failures (clair, clamav, SAST)
   - Signing failures (image signature issues)
4. Common issues:
   - Multistage Dockerfile issue (final stage too large)
   - Base image vulnerabilities
   - Embedded secrets (catch-all scan)

## Attachment vs Embedded Results

- **Embedded results:** Part of Tekton task result (4KB limit)
- **Attached results:** OCI artifacts stored separately, linked via digest

Large scan reports are attached via `oras push` in `oci-attach-report` step.

**Access attached reports:**

```bash
oras pull <image>@<digest> --output /tmp/
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Result JSON malformed | Validate with `jq` before returning result. Use `jq -r @json` to escape. |
| Result too large (>4KB) | Use OCI artifact attachment for large output. Summarize in embedded result. |
| Image pull fails silently | Check docker/podman auth is configured. Verify image exists. |
| Task times out | Check `timeout` parameter in PipelineRun. Increase if legitimate operation is slow. |
| OCI artifact attach fails | Verify registry credentials. Check storage quota. Ensure oras binary is in image. |
| Conftest policy fails unexpectedly | Review policies in `policies/`. Add `--debug` flag to conftest for verbose output. |
| CA certificate validation fails | Mount CA trust ConfigMap via `ca-trust-config-map-name` parameter. |
