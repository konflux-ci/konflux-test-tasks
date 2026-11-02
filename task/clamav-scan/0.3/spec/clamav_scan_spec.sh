#!/usr/bin/env bash
set -euo pipefail

eval "$(shellspec - -c) exit 1"

task_path="../clamav-scan.yaml"

if [[ ! -f "${task_path}" ]]; then
    echo "ERROR: Task file not found: ${task_path}"
    exit 1
fi

task_script="$(mktemp --tmpdir clamav-scan-script_XXXXXXXXXX.sh)"
platform_helpers="$(mktemp --tmpdir clamav-scan-platform-helpers_XXXXXXXXXX.sh)"
yq -r '.spec.steps[] | select(.name == "extract-and-scan-image").script' "${task_path}" > "${task_script}"
awk '
  /^# BEGIN PLATFORM HELPERS$/ { capture = 1; next }
  /^# END PLATFORM HELPERS$/ { capture = 0 }
  capture
' "${task_script}" > "${platform_helpers}"
# shellcheck source=/dev/null
. "${platform_helpers}"

cleanup() {
    rm -f "${task_script}" "${platform_helpers}"
}
trap cleanup EXIT

Describe "platform-aware image handling"
    It "keeps operating systems distinct when they share an architecture"
        manifest_index='{"manifests":[{"digest":"sha256:linux","platform":{"os":"linux","architecture":"amd64"}},{"digest":"sha256:windows","platform":{"os":"windows","architecture":"amd64","os.version":"10.0.20348.2402"}},{"digest":"sha256:darwin","platform":{"os":"darwin","architecture":"arm64","variant":"v8"}}]}'

        When call platform_manifests_from_index "${manifest_index}"
        The output should eq '[{"os":"linux","architecture":"amd64","variant":"","digest":"sha256:linux"},{"os":"windows","architecture":"amd64","variant":"","digest":"sha256:windows"},{"os":"darwin","architecture":"arm64","variant":"v8","digest":"sha256:darwin"}]'
    End

    It "gets the platform from a single-image config"
        image_config='{"architecture":"arm64","os":"darwin"}'

        When call platform_manifest_from_config "${image_config}" "sha256:darwin"
        The output should eq '[{"os":"darwin","architecture":"arm64","variant":"","digest":"sha256:darwin"}]'
    End

    It "selects a Windows platform and normalizes x86_64"
        platform_manifests='[{"os":"linux","architecture":"amd64","variant":"","digest":"sha256:linux"},{"os":"windows","architecture":"amd64","variant":"","digest":"sha256:windows"}]'

        When call select_platform_manifests "${platform_manifests}" "windows/x86_64"
        The output should eq '[{"os":"windows","architecture":"amd64","variant":"","digest":"sha256:windows"}]'
    End

    It "accepts mac as an alias for the OCI darwin platform"
        platform_manifests='[{"os":"linux","architecture":"amd64","variant":"","digest":"sha256:linux"},{"os":"darwin","architecture":"arm64","variant":"","digest":"sha256:darwin"}]'

        When call select_platform_manifests "${platform_manifests}" "mac/arm64"
        The output should eq '[{"os":"darwin","architecture":"arm64","variant":"","digest":"sha256:darwin"}]'
    End

    It "selects an OCI platform variant"
        platform_manifests='[{"os":"linux","architecture":"arm64","variant":"v8","digest":"sha256:v8"},{"os":"linux","architecture":"arm64","variant":"v9","digest":"sha256:v9"}]'

        When call select_platform_manifests "${platform_manifests}" "linux/arm64/v8"
        The output should eq '[{"os":"linux","architecture":"arm64","variant":"v8","digest":"sha256:v8"}]'
    End

    It "selects every operating system for an architecture-only request"
        platform_manifests='[{"os":"linux","architecture":"amd64","variant":"","digest":"sha256:linux"},{"os":"windows","architecture":"amd64","variant":"","digest":"sha256:windows"}]'

        When call select_platform_manifests "${platform_manifests}" "amd64"
        The output should eq '[{"os":"linux","architecture":"amd64","variant":"","digest":"sha256:linux"},{"os":"windows","architecture":"amd64","variant":"","digest":"sha256:windows"}]'
    End

    It "preserves the legacy Linux result suffix"
        When call platform_log_suffix "linux" "amd64" ""
        The output should eq "amd64"
    End

    It "includes the operating system in non-Linux result suffixes"
        When call platform_log_suffix "windows" "amd64" ""
        The output should eq "windows-amd64"
    End

    It "encodes unsafe manifest fields before using them in paths"
        When call platform_log_suffix "windows/../../tmp/pwn" "amd64/../../escape" "v8/../../logs"
        The output should eq "windows-tmp-pwn-amd64-escape-v8-logs"
    End

    It "retries raw manifest inspection"
        # shellcheck disable=SC2329 # Invoked indirectly by the extracted task helper.
        retry() {
            echo "$*"
        }
        export -f retry

        When call inspect_raw_manifest "registry.example/image@sha256:image"
        The output should eq "skopeo inspect --raw --authfile ${HOME}/.docker/config.json docker://registry.example/image@sha256:image"
    End

    It "retries image config inspection"
        # shellcheck disable=SC2329 # Invoked indirectly by the extracted task helper.
        retry() {
            echo "$*"
        }
        export -f retry

        When call inspect_image_config "registry.example/image@sha256:image"
        The output should eq "skopeo inspect --config --authfile ${HOME}/.docker/config.json docker://registry.example/image@sha256:image"
    End

    It "passes the Windows platform when extracting a layer"
        # shellcheck disable=SC2329 # Invoked indirectly by the extracted task helper.
        retry() {
            echo "$*"
        }
        export -f retry

        When call extract_image_layer "registry.example/image@sha256:windows" "sha256:layer" "content-windows-amd64" "windows/amd64"
        The output should eq "oc image extract --confirm --only-files=true --registry-config ${HOME}/.docker/config.json registry.example/image@sha256:windows[~sha256:layer] --path=/:content-windows-amd64 --filter-by-os=windows/amd64"
    End

    It "passes the Darwin platform when listing a layer"
        # shellcheck disable=SC2329 # Invoked indirectly by the extracted task helper.
        retry() {
            echo "$*"
        }
        export -f retry

        When call list_image_layer "registry.example/image@sha256:darwin" "sha256:layer" "content-darwin-arm64" "darwin/arm64"
        The output should eq "oc image extract --dry-run --confirm --registry-config ${HOME}/.docker/config.json registry.example/image@sha256:darwin[~sha256:layer] --path=/:content-darwin-arm64 --filter-by-os=darwin/arm64"
    End


    It "passes the Windows platform when extracting a full image"
        # shellcheck disable=SC2329 # Invoked indirectly by the extracted task helper.
        retry() {
            echo "$*"
        }
        export -f retry

        When call extract_full_image "registry.example/image@sha256:windows" "content-windows-amd64" "windows/amd64"
        The output should eq "oc image extract --confirm --only-files=true --registry-config ${HOME}/.docker/config.json registry.example/image@sha256:windows --path=/:content-windows-amd64 --filter-by-os=windows/amd64"
    End
End
