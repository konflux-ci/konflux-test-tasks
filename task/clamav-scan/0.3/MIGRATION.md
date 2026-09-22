# Migration from 0.3.3 to 0.3.4

Version 0.3.4 improves how archived content is scanned. Instead of handing the
packed archive blob to clamd (which recurses into it entry-by-entry), the task now
**pre-extracts every nested archive into a loose file tree** and scans that, so
clamd scans each file directly. This makes scanning of deeply nested archives
faster.

Extraction is unconditional: all nested archives (zip/jar/war/ear/tar and
tar.gz/tar.bz2/tar.xz, detected by content rather than file extension) are unpacked
in place with `bsdtar` and the resulting loose tree is scanned. There are no
extraction limits and no new parameters. Extraction is defensive — a corrupt or
partial archive is left in place for clamd rather than aborting the scan.

This relies on the `clamav-db` image shipping `bsdtar`; that dependency is added in
the konflux-clamav repo and reaches `quay.io/konflux-ci/clamav-db:latest` via the
image's normal build/release.

## Action from users

No action is required and there are no new parameters to set. Note that content
containing very large or decompression-bomb archives is unpacked in full, which
increases the task's ephemeral disk usage for the duration of the scan.

---

# Migration from 0.3.2 to 0.3.3

Version 0.3.3 skips **downloading** OCI layers when the image manifest already
names a model-weight file (olot annotations `org.opencontainers.image.title` /
`olot.layer.content.inlayerpath` ending in `.safetensors`, `.gguf`, `.ggml`,
`.pt`, `.pth`, `.onnx`, `.onnx_data`, or `.onnx_data_*`). Any other annotated
layer is skipped when the OCI descriptor `size` is at least 2000MiB.
Layers without those annotations still use `--dry-run` listing as in 0.3.2
(same name list). Task parameters and results are unchanged.

## Action from users

No action is required. MintMaker will bump the task bundle reference.

---

# Migration from 0.3.1 to 0.3.2

Version 0.3.2 skips unpacking OCI layers that contain only model-weight files
ClamAV cannot scan (`.safetensors`, `.gguf`, `.ggml`). Task parameters and
results are unchanged.

## Action from users

No action is required. MintMaker will bump the task bundle reference.

---

# Migration from 0.2 to 0.3

Version 0.3:

On this version clamscan is replaced by clamdscan which can scan an image in parallel (8 threads by default).
Besides that, if the pipelinerun uses a matrix configuration for the task, each arch will create a separate TaskRun, running in parallel.

Changes:
- The `image-arch` parameter definition is added and the defaul value is "".
- The `clamd-max-threads` parameter definition is added and the default is 8.
- For multi-architecture builds, `matrix` is added to the build pipeline definition file.

## Action from users

Renovate bot PR will be created with warning icon for a clamav-scan which is expected, no actions from users are required for the task.

For multi-arch build, `matrix` will be added to build pipeline definition file automatically by script migrations/0.3.sh when MintMaker runs [pipeline-migration-tool](https://github.com/konflux-ci/pipeline-migration-tool).
