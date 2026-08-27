# Changelog

<!-- Format guidelines: https://keepachangelog.com/en/1.1.0/#how -->

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

## 0.3

### Changed

- Replaced clamscan with clamdscan for parallel scanning support.
- Added `image-arch` parameter for multi-architecture builds.
- Added `clamd-max-threads` parameter with default of 8 threads.

## 0.2

### Changed

- Removed sidecar from the task; required tools added to the ClamAV container image.

## 0.1

### Added

- Initial version of the `clamav-scan` task.
