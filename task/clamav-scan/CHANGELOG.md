# Changelog

<!-- Format guidelines: https://keepachangelog.com/en/1.1.0/#how -->

## 0.3.7

### Changed

- Run `clamd` as the `clamav` user. The extract step stays root so
  `start-clamd.sh` can rewrite `/etc/clamd.d/scan.conf` and so `clamd` honors
  its `User` directive. `clamdscan --fdpass` opens the extracted files.
- Drop every capability on the extract step and set
  `allowPrivilegeEscalation: false`. Nested `bsdtar` extraction no longer
  restores owner, permissions, ACLs, file flags, or extended attributes, so
  unpacking still succeeds with that capability set.

## 0.3.6

### Fixed

- Normalize Konflux node-pool suffixes in `image-arch` before selecting an OCI
  manifest. A scheduling label such as `linux-m2xlarge/arm64` is treated as
  `linux/arm64`, so the scan matches the image manifest.

## 0.3.5

### Added

- Scan Linux, Windows, and macOS container images by retaining each manifest's
  OCI operating system and architecture during platform selection and layer
  extraction. The `image-arch` parameter now accepts full OCI platforms and
  recognizes `mac`, `macos`, and `osx` as aliases for `darwin`.

## 0.3.4

### Added

- Pre-extract every nested archive into a loose file tree before scanning, so
  clamd scans each file directly instead of recursing through nested archive
  layers. This makes scanning of deeply nested archives faster. Extraction uses
  `bsdtar`, which detects archives (zip/jar/war/ear/tar
  and tar.gz/tar.bz2/tar.xz) by content rather than extension — important because
  the OCI `dir:` payload is an extension-less blob — and unpacks them
  unconditionally with no size/count/depth limits. It is defensive: a corrupt or
  partial archive is left in place for clamd rather than aborting the scan. No new
  parameters are introduced. Requires the `clamav-db` image to ship `bsdtar`
  (added in konflux-clamav).

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
