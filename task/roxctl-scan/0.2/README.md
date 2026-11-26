# roxctl-scan task

## Description:
The roxctl-scan task performs vulnerability scanning using Roxctl, an tool for performing static analysis
on container images provided by ACS. Roxctl is specifically designed for scanning container images for security issues by
analyzing the components of a container image and comparing them against ACS vulnerability databases. Fetches all RHSAs for critical and
important vulnerabilities.

## Params:

| name         | description                                                     | default |
|--------------|-----------------------------------------------------------------|-|
| image-digest | Image digest to scan.                                           | None |
| image-url    | Image URL.                                                      | None |
| rox_central_endpoint | The address:port tuple for RHACS Stackrox Central | https://acs-d4dgfbkto15c73biblcg.acs.rhcloud.com |
| client-timeout | How long roxctl waits for each RHACS scan request before timing out. Use a Go duration, such as `10m` or `30m`. Set this to a higher value for larger images. Some large images may need up to 30m. (Roxctl retries failed requests up to three times.) | 10m |

## Results:

| name              | description              |
|-------------------|--------------------------|
| TEST_OUTPUT | Tekton task test output. |
| SCAN_OUTPUT | Roxctl scan result.       |
| ACS_RHSAS | RHSAs found from roxctl-scan parsed output.       |

## Roxctl-action documentation:
https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/4.0/html-single/roxctl_cli/index

## Source repository for image:
https://catalog.redhat.com/en/software/containers/advanced-cluster-security/rhacs-roxctl-rhel8/610bfc32dd1aaa9129b0d4bc

