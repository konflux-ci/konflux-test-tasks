# Changelog

<!-- Format guidelines: https://keepachangelog.com/en/1.1.0/#how -->

## 0.1.2

### Added

- Optional `FETCH_EXTRA_ARTIFACTS` and `EXTRA_ARTIFACT_FILTER` parameters
  to fetch pickle-like files (`.pkl`, `.pickle`, `.pt`, `.pth`, `.bin`,
  `.ckpt`, `.joblib`) from `image-url@image-digest` into the scan tree
  alongside `SOURCE_ARTIFACT`. Default remains off.

## 0.1.1

### Removed

- SCAN_OUTPUT result has been removed as it wasn't compatible with standardized Konflux UI

## 0.1

### Added

- Initial release of pickle-scan-oci-ta task (trusted artifacts variant)
- Scans OCI artifacts and AI model files for malicious pickle content using picklescan
- Attaches scan report to OCI image registry
- Generates TEST_OUTPUT and SCAN_OUTPUT results via rego policy evaluation
