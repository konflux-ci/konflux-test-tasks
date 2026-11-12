# calculate-safe-dates task

## Description:
The calculate-safe-dates task performs date calculation for given RHSAs that were found in ACS-scan.
Given ranges are 30 days for critical RHSA and 90 days for important(high) ones.
Users are informed about the findings via console log and a status result.
Following cases might occur:
- no RHSAs found: fail fast, final result is PASS
- RHSAs found within the date range: final result is WARNING
- RHSAs found outside of date range: final result is BLOCK/FAILED

## Params:

| name                     | description                                                            | default |
|--------------------------|------------------------------------------------------------------------|-|
| rhsas-found              | Reported from roxctl-scan, found critical and/or important RHSAs.       | None |

## Results:

| name        | description              |
|-------------|--------------------------|
| TEST_OUTPUT | Tekton task test output. |

## Additional links:
https://docs.redhat.com/en/documentation/red_hat_security_data_api/1.0/security_data_api-security_data_api_overview
