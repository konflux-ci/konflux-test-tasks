# Changelog

<!-- Format guidelines: https://keepachangelog.com/en/1.1.0/#how -->

## 0.1.3

### Fixed

- Align with KONFLUX-14352 / KONFLUX-15254 resource policy: drop `limits.cpu` on all steps; keep existing `requests` (`pickle-scan` 2Gi/800m, `oci-attach-report` and `evaluate-policy` 256Mi/100m).

## 0.1.2

### Changed

- Version aligned with pickle-scan-oci-ta 0.1.2. No functional changes
  to the workspace task.

## 0.1.1

### Removed

- SCAN_OUTPUT result has been removed as it wasn't compatible with standardized Konflux UI

## 0.1

### Added

- Initial release of pickle-scan task
- Scans OCI artifacts and AI model files for malicious pickle content using picklescan
- Attaches scan report to OCI image registry
- Generates TEST_OUTPUT and SCAN_OUTPUT results via policy evaluation
