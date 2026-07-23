# pickle-scan task

## Description:

Scans OCI artifacts and AI model files for malicious pickle files using
[picklescan](https://github.com/mmaitre314/picklescan). Pickle files are
commonly used for Python/ML model serialization and can contain arbitrary
code execution payloads.

## Params:

| Name | Description | Default |
|------|-------------|---------|
| image-url | Image URL | (required) |
| image-digest | Image digest to scan | (required) |
| ca-trust-config-map-name | ConfigMap name for CA bundle | `trusted-ca` |
| ca-trust-config-map-key | Key in ConfigMap for CA bundle | `ca-bundle.crt` |
| skip-oci-attach-report | Skip uploading report to registry | `false` |

## Workspaces

| Name | Description |
|------|-------------|
| source | Directory containing model files to scan for malicious pickle content |

## Results

| Name | Description |
|------|-------------|
| TEST_OUTPUT | Tekton task test output |
| IMAGES_PROCESSED | Images processed in the task |

## Trusted Artifacts variant

A Trusted Artifacts variant of this task,
[pickle-scan-oci-ta](../../pickle-scan-oci-ta/0.1/pickle-scan-oci-ta.yaml),
consumes the files to scan via the `SOURCE_ARTIFACT` parameter instead of
the `source` workspace.
