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
