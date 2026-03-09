# clamav-scan-min task

Scans the content of container images and OCI artifacts for viruses, malware, and other malicious content using ClamAV antivirus scanner.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|image-digest|Image digest to scan.||true|
|image-url|Image URL.||true|
|image-arch|Image arch.|""|false|
|docker-auth|unused|""|false|
|ca-trust-config-map-name|The name of the ConfigMap to read CA bundle data from.|trusted-ca|false|
|ca-trust-config-map-key|The name of the key in the ConfigMap that contains the CA bundle data.|ca-bundle.crt|false|
|clamd-max-threads|Maximum number of threads clamd runs.|8|false|
|skip-upload|If true, skips uploading the results to the image registry. Useful for read-only tests.|false|false|

## Results
|name|description|
|---|---|
|TEST_OUTPUT|Tekton task test output.|
|IMAGES_PROCESSED|Images processed in the task.|

