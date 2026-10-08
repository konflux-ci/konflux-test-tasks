# clamav-scan task

## Description:
The clamav-scan task scans files for viruses and other malware using the ClamAV antivirus scanner.
ClamAV is an open-source antivirus engine that can be used to check for viruses, malware, and other malicious content.
The task will extract compiled code to compare it against the latest virus database to identify any potential threats.
The logs will provide both the version of ClamAV and the version of the database used in the comparison scan.

## Version 0.3:
On this version clamscan is replaced by clamdscan which can scan an image in parallel (8 threads by default).
Besides that, if the pipeline task uses a matrix configuration for the task, each arch will create a separate TaskRun, running in parallel.

## Version 0.3.2:
For container images, the extract step lists each OCI layer and skips layers
that contain only unscannable model-weight files (`.safetensors`, `.gguf`,
`.ggml`). Those layers are still downloaded so filenames can be listed; they
are not unpacked or passed to `clamdscan`. Mixed or unknown layers, and any
layer that cannot be listed, are extracted as before. OCI artifacts are
unchanged. Skipped layers are recorded in the ClamAV log.

## Version 0.3.3:
When an OCI layer descriptor already names the file (olot ModelCar annotations
`org.opencontainers.image.title` / `olot.layer.content.inlayerpath`), weight
layers (`.safetensors`, `.gguf`, `.ggml`, `.pt`, `.pth`, `.onnx`, `.onnx_data`
/ `.onnx_data_*`) are skipped without downloading the blob. Any other
annotated layer is skipped when the descriptor `size` is at least 2000MiB
(slightly under ClamAV's ~2GiB MaxFileSize), regardless of extension.
`--dry-run` listing is used when those annotations are absent (same name
list).

## Version 0.3.5:
The new `archive-extraction-mode` parameter selects `legacy` serial extraction
or the `accelerated` extractor supplied by the `clamav-db` image. It defaults to
`legacy` so existing users keep the previous behavior. Concurrent extractions
are bounded by `archive-extraction-workers` (default: `8`), independently of
`clamd-max-threads`; detection remains content-based, and
processing falls back to the serial extractor if the accelerated implementation
is unavailable or fails.

Failed archive extraction emits a warning and scanning continues with the
original archive retained. ClamAV scans retained archives as raw files because
internal archive scanning is disabled. Output-path collisions remain fatal.

## --max-filesize: 
Is set to the same value as the default value according to the ClamAV official Documentation.

https://wiki.debian.org/ClamAV

https://docs.clamav.net/manual/Development/tips-and-tricks.html?highlight=max-filesize#general-debugging 

## Params:

| name                     | description                                                            | default       |
|--------------------------|------------------------------------------------------------------------|---------------|
| image-digest             | Image digest to scan.                                                  | None          |
| image-url                | Image URL.                                                             | None          |
| image-arch               | Image arch.                                                            | None          |
| docker-auth              | Unused, should be removed in next task version.                        |               |
| ca-trust-config-map-name | The name of the ConfigMap to read CA bundle data from.                 | trusted-ca    |
| ca-trust-config-map-key  | The name of the key in the ConfigMap that contains the CA bundle data. | ca-bundle.crt |
| clamd-max-threads        | Maximum number of threads clamd runs.                                 | 8             |
| archive-extraction-mode  | Archive pre-extraction implementation: `legacy` or `accelerated`.        | legacy        |
| archive-extraction-workers | Maximum concurrent archive extractions in accelerated mode; positive integer, ignored in legacy mode. | 8 |

## Results:

| name               | description               |
|--------------------|---------------------------|
| TEST_OUTPUT  | Tekton task test output.  |

## Source repository for image:
https://github.com/konflux-ci/konflux-test/tree/main/clamav

## Additional links:
https://docs.clamav.net/
