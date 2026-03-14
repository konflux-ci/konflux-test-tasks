# tpa-scan task

## Description:
The tpa-scan task performs vulnerability scanning for container images using the Red Hat Trusted Profile Analyzer service, 
part of Red Hat Trusted Software Supply Chain.
TPA is specifically designed for scanning container image SBOMs for security issues by
analyzing the components of a container image and comparing them against the vulnerability databases.

## Params:

| name                     | description                                                            | default |
|--------------------------|------------------------------------------------------------------------|-|
| image-digest             | Image digest to scan.                                                  | None |
| image-url                | Image URL.                                                             | None |
| tpa-url                  | URL of the TPA instance to be used for scanning.                       | None |
| ca-trust-config-map-name | The name of the ConfigMap to read CA bundle data from.                 | trusted-ca |
| ca-trust-config-map-key  | The name of the key in the ConfigMap that contains the CA bundle data. | ca-bundle.crt |

## Results:

| name        | description              |
|-------------|--------------------------|
| TEST_OUTPUT | Tekton task test output. |
| SCAN_RESULT | TPA scan result.         |

## Additional links:
https://developers.redhat.com/products/trusted-profile-analyzer
