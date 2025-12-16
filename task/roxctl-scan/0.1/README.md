# roxctl-scan task

## Description:
The roxctl-scan task performs vulnerability scanning using Roxctl, an tool for performing static analysis
on container images provided by ACS. Roxctl is specifically designed for scanning container images for security issues by
analyzing the components of a container image and comparing them against ACS vulnerability databases.

## Params:

| name         | description                                                     | default |
|--------------|-----------------------------------------------------------------|-|
| image-digest | Image digest to scan.                                           | None |
| image-url    | Image URL.                                                      | None |
| ca-trust-config-map-name|The name of the ConfigMap to read CA bundle data from.| trusted-ca |
| ca-trust-config-map-key |The name of the key in the ConfigMap that contains the CA bundle data.| ca-bundle.crt |

## Results:

| name              | description              |
|-------------------|--------------------------|
| TEST_OUTPUT | Tekton task test output. |
| SCAN_OUTPUT | Roxctl scan result.       |

## Roxctl-action documentation:
https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/4.0/html-single/roxctl_cli/index

## Source repository for image:
https://catalog.redhat.com/en/software/containers/advanced-cluster-security/rhacs-roxctl-rhel8/610bfc32dd1aaa9129b0d4bc

