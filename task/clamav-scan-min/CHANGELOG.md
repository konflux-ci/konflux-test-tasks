# Changelog

<!-- Format guidelines: https://keepachangelog.com/en/1.1.0/#how -->

## Unreleased

<!--
When you make changes without bumping the version right away, document them here.
If that's not something you ever plan to do, consider removing this section.
-->

*Nothing yet.*

## 0.3.3

### Changed

- Skip downloading OCI layers whose manifest annotations name only unscannable
  model-weight files (`.safetensors`, `.gguf`, `.ggml`, `.pt`, `.pth`, `.onnx`,
  `.onnx_data` / `.onnx_data_*`), using `org.opencontainers.image.title` and
  `olot.layer.content.inlayerpath`. Any other annotated layer is skipped when
  the OCI descriptor `size` is at least 2000MiB (slightly under ClamAV's ~2GiB
  MaxFileSize), regardless of extension. Layers without those annotations are
  still listed with `--dry-run` as in 0.3.2. The `--dry-run` skip uses the
  same name list.

## 0.3.2

### Added

- Skip extracting OCI layers that contain only unscannable model-weight files
  (`.safetensors`, `.gguf`, `.ggml`). Other layers are still extracted and
  scanned. If layer listing fails, the task falls back to extracting the
  full image.

## 0.3.1

### Changed

- Replaced `quay.io/konflux-ci/oras:latest` image with `quay.io/konflux-ci/task-runner:1.5.0` in the upload step.

## 0.3

### Added

- Started tracking changes in this file.
