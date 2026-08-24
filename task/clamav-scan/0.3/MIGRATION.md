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
