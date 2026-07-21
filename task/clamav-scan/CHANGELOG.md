# Changelog

<!-- Format guidelines: https://keepachangelog.com/en/1.1.0/#how -->

## 0.3

### Changed

- Replaced clamscan with clamdscan for parallel scanning support.
- Added `image-arch` parameter for multi-architecture builds.
- Added `clamd-max-threads` parameter with default of 8 threads.

## 0.2

### Changed

- Removed sidecar from the task; required tools added to the ClamAV container image.

## 0.1

### Added

- Initial version of the `clamav-scan` task.
