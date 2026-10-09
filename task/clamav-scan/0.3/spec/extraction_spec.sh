#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

eval "$(shellspec - -c) exit 1"

# Exercise the actual YAML functions and scan call, not a copied implementation.
prepare_fixture() {
    fixture=$(mktemp -d)
    export ARCHIVE_EXTRACTION_MODE="$2" ARCHIVE_EXTRACTION_WORKERS=2 MAX_THREADS=7
    export WORKERS_LOG="$fixture/workers.log" FAIL_EXTRACTION=0
    task_path="../../../$1/0.3/$1.yaml"
    yq -r '.spec.steps[] | select(.name == "extract-and-scan-image").script' \
        "$task_path" > "$fixture/step.sh"
    {
        printf 'set -euo pipefail\n'
        awk '
            /extract_archives_serial\(\)/ { copying=1 }
            copying && /^# Start clamd in background/ { exit }
            copying { print }
        ' "$fixture/step.sh"
        printf 'destination=$1\nsuffix=test\n'
        awk '
            /^ *extract_archives "\$\{destination\}"/ { copying=1 }
            copying { print }
            copying && /\|\| true$/ { exit }
        ' "$fixture/step.sh" | sed "s|/work/logs/|$fixture/|g"
        printf 'printf scanned > "$2"\n'
    } > "$fixture/run.sh"
    mkdir "$fixture/content"
    printf 'original archive' > "$fixture/content/input.archive"
}

cleanup_fixture() {
    # fixture is always a dedicated mktemp directory, never a payload directory.
    rm -rf "${fixture:?}"
}

run_extraction() {
    bash "$fixture/run.sh" "$fixture/content" "$fixture/scanned"
}

symlink_target() {
    readlink "$collision"
}

Describe 'archive extraction in both task variants'
    AfterEach cleanup_fixture

    Mock bsdtar
        if [[ $1 == -tf ]]; then
            [[ $2 == *.archive ]] && echo payload
        elif [[ $FAIL_EXTRACTION == 1 ]]; then
            # Simulate bsdtar failing; the task must still continue scanning.
            exit 1
        else
            printf payload > "$4/payload"
        fi
    End

    Mock clamav-extract-archives
        printf '%s\n' "$1" "$2" > "$WORKERS_LOG"
        exit 23
    End

    Describe 'successful serial extraction and accelerated fallback'
        Parameters:matrix
            clamav-scan clamav-scan-min
            legacy accelerated
        End

        It "extracts successfully before scanning ($1, $2)"
            prepare_fixture "$1" "$2"
            When call run_extraction
            The status should be success
            The stderr should be blank
            if [[ $2 == accelerated ]]; then
                The output should include 'using serial extraction'
                The contents of file "$WORKERS_LOG" should equal "$(printf '%s\n' --workers 2)"
            else
                The output should be blank
                The file "$WORKERS_LOG" should not be exist
            fi
            The file "$fixture/scanned" should be exist
            The file "$fixture/content/input.archive" should not be exist
            The contents of file "$fixture/content/input.archive.d/payload" should equal payload
        End
    End

    Describe 'best-effort scanning after failed extraction'
        Parameters:matrix
            clamav-scan clamav-scan-min
            legacy accelerated
        End

        It "warns and retains the archive while continuing ($1, $2)"
            prepare_fixture "$1" "$2"
            export FAIL_EXTRACTION=1
            When call run_extraction
            The status should be success
            The output should include 'continuing with best-effort scanning'
            The stderr should be blank
            if [[ $2 == accelerated ]]; then
                The output should include 'using serial extraction'
            fi
            The file "$fixture/scanned" should be exist
            The contents of file "$fixture/content/input.archive" should equal 'original archive'
            The path "$fixture/content/input.archive.d" should not be exist
        End
    End

    Describe 'output-path collision protection'
        Parameters:matrix
            clamav-scan clamav-scan-min
            legacy accelerated
            directory file symlink
        End

        It "warns and continues without modifying existing data ($1, $2, $3)"
            prepare_fixture "$1" "$2"
            collision="$fixture/content/input.archive.d"
            case "$3" in
                directory) mkdir "$collision"; printf existing > "$collision/marker" ;;
                file) printf existing > "$collision" ;;
                symlink) ln -s missing-target "$collision" ;;
            esac
            When call run_extraction
            The status should be success
            The output should include 'cannot create extraction output'
            The output should include 'continuing with best-effort scanning'
            The stderr should be blank
            The file "$fixture/scanned" should be exist
            The contents of file "$fixture/content/input.archive" should equal 'original archive'
            case "$3" in
                directory)
                    The contents of file "$collision/marker" should equal existing
                    The file "$collision/payload" should not be exist
                    ;;
                file)
                    The contents of file "$collision" should equal existing
                    ;;
                symlink)
                    The path "$collision" should be symlink
                    The result of function symlink_target should equal missing-target
                    ;;
            esac
        End
    End

    Describe 'invalid extraction mode'
        Parameters
            clamav-scan
            clamav-scan-min
        End

        It "warns and uses legacy extraction before scanning ($1)"
            prepare_fixture "$1" invalid
            When call run_extraction
            The status should be success
            The stderr should include 'using legacy extraction'
            The output should be blank
            The file "$WORKERS_LOG" should not be exist
            The file "$fixture/scanned" should be exist
            The file "$fixture/content/input.archive" should not be exist
            The contents of file "$fixture/content/input.archive.d/payload" should equal payload
        End
    End

    Describe 'missing extraction mode'
        Parameters:matrix
            clamav-scan clamav-scan-min
            empty unset
        End

        It "warns and uses legacy/bsdtar extraction ($1, $2)"
            prepare_fixture "$1" ""
            if [[ $2 == unset ]]; then
                unset ARCHIVE_EXTRACTION_MODE
            fi
            When call run_extraction
            The status should be success
            The stderr should include 'ARCHIVE_EXTRACTION_MODE was not provided; falling back to legacy/bsdtar extraction'
            The output should be blank
            The file "$WORKERS_LOG" should not be exist
            The file "$fixture/scanned" should be exist
            The file "$fixture/content/input.archive" should not be exist
            The contents of file "$fixture/content/input.archive.d/payload" should equal payload
        End
    End
End
