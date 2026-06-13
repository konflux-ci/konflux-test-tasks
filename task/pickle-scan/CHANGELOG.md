# Changelog

<!-- Format guidelines: https://keepachangelog.com/en/1.1.0/#how -->

## 0.1

### Added

- Initial release of pickle-scan task
- Scans OCI artifacts and AI model files for malicious pickle content using picklescan
- Attaches scan report to OCI image registry
- Generates TEST_OUTPUT and SCAN_OUTPUT results via conftest policy evaluation
