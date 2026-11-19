# Changelog

<!-- Format guidelines: https://keepachangelog.com/en/1.1.0/#how -->

## 0.2.1

### Fixed

- Fixed invalid JSON escape sequences in roxctl scan output that caused jq parsing failures

## 0.2

### Added

- Added new result: **ACS_RHSAS** that contains found critical and important CVEs RHSAS
- Added new step: **get-rhsas** fetches all critical and important RHSAs from parsed roxctl-scan output and stores it in the result mentioned above

## 0.1.2

### Fixed

- Fixed invalid JSON escape sequences in roxctl scan output that caused jq parsing failures

## 0.1.1

### Changed

- Updated rox-image-scan and exchange-service-account-token steps image to version *4.11.5* by following digest registry.redhat.io/advanced-cluster-security/rhacs-roxctl-rhel9@sha256:98f01d623e119acbbc211bdeb36192b619969aa149d9c66bab8034eeef84c861 

## 0.1

### Added

- Initial version of the `roxctl-scan` task.
