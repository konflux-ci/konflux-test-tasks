#!/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

eval "$(shellspec - -c) exit 1"

# Path to task YAML relative to spec/ directory
task_path="../roxctl-scan.yaml"

if [[ ! -f "${task_path}" ]]; then
    echo "ERROR: Task file not found: ${task_path}"
    exit 1
fi

# Array containing files/directories to remove on test exit
cleanup=()
trap 'rm -rf "${cleanup[@]}"' EXIT

# Build a standalone sanitizer script by extracting the actual sed commands
# from the proccess-output step in the task YAML. This ensures tests exercise
# the real implementation, not duplicated code.
build_sanitizer() {
    local script_file
    script_file="$(mktemp --tmpdir sanitizer_XXXXXXXXXX.sh)"
    {
        echo '#!/bin/bash'
        echo 'set -euo pipefail'
        echo 'rox_file="$1"'
        yq -r '.spec.steps[] | select(.name == "proccess-output").script' "$task_path" \
          | awk '/STONEINTG-1878/,/jq -s/' \
          | sed '$d'
    } > "$script_file"
    chmod +x "$script_file"
    echo "$script_file"
}

sanitizer_script="$(build_sanitizer)"
cleanup+=("${sanitizer_script}")

testdir() {
    testdir="$(mktemp -d)" && cleanup+=("${testdir}") && cd "${testdir}"
    AfterEach "rm -rf $testdir"
}

# Run the extracted sanitizer on a file
fix_json_escapes() {
    "$sanitizer_script" "$1"
}

Describe "roxctl scan JSON escape sanitization"
    BeforeEach testdir

    Describe "invalid escape repair (STONEINTG-1899)"
        It "fixes backslash-paren that breaks jq"
            printf '{"summary": "foo\\(bar)"}' > test.json
            fix_json_escapes test.json
            When call jq -r '.summary' test.json
            The status should be success
            The output should equal 'foo\(bar)'
        End

        It "fixes backslash-bracket sequences"
            printf '{"path": "a\\[0\\]"}' > test.json
            fix_json_escapes test.json
            When call jq -r '.path' test.json
            The status should be success
            The output should equal 'a\[0\]'
        End

        It "fixes multiple invalid escapes in one value"
            printf '{"v": "a\\(b\\)c\\[d\\]"}' > test.json
            fix_json_escapes test.json
            When call jq -r '.v' test.json
            The status should be success
            The output should equal 'a\(b\)c\[d\]'
        End

        It "produces valid JSON parseable by jq"
            printf '{"s": "has \\(invalid\\) escapes"}' > test.json
            fix_json_escapes test.json
            When call jq -r '.s' test.json
            The status should be success
            The output should equal 'has \(invalid\) escapes'
        End
    End

    Describe "valid escape preservation"
        It "preserves backslash-n newline escape"
            printf '{"t": "line1\\nline2"}' > test.json
            cp test.json expected.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal "$(cat expected.json)"
        End

        It "preserves backslash-t tab escape"
            printf '{"t": "col1\\tcol2"}' > test.json
            cp test.json expected.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal "$(cat expected.json)"
        End

        It "preserves escaped quote"
            printf '{"t": "say \\\\"hello\\\\""}' > test.json
            cp test.json expected.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal "$(cat expected.json)"
        End

        It "preserves valid backslash pair"
            printf '{"p": "foo\\\\bar"}' > test.json
            cp test.json expected.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal "$(cat expected.json)"
        End

        It "preserves unicode escape"
            printf '{"u": "\\u0041"}' > test.json
            cp test.json expected.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal "$(cat expected.json)"
        End

        It "preserves solidus escape"
            printf '{"p": "a\\/b"}' > test.json
            cp test.json expected.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal "$(cat expected.json)"
        End

        It "leaves already-valid JSON completely unchanged"
            printf '{"a":"clean","b":"no\\\\issues","c":"with\\nnewline"}' > test.json
            cp test.json expected.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal "$(cat expected.json)"
        End
    End

    Describe "Go fmt artifact cleanup (STONEINTG-1878)"
        It "cleans MISSING pattern"
            printf '{"s": "value %%!s(MISSING) here"}' > test.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal '{"s": "value %s here"}'
        End

        It "cleans NOVERB pattern"
            printf '{"s": "extra %%!(NOVERB)"}' > test.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal '{"s": "extra %"}'
        End
    End

    Describe "combined Go fmt and backslash fix"
        It "handles Go fmt artifacts followed by invalid escapes"
            printf '{"s": "%%!s(MISSING) in \\(path\\)"}' > test.json
            fix_json_escapes test.json
            When call jq -r '.s' test.json
            The status should be success
            The output should equal '%s in \(path\)'
        End
    End

    Describe "triple backslash edge case"
        It "correctly handles odd-count backslashes before invalid char"
            # Three backslashes + paren: valid-pair \\ + invalid \(
            printf '{"v": "x\\\\\\(y"}' > test.json
            fix_json_escapes test.json
            When call jq -r '.v' test.json
            The status should be success
            The output should equal 'x\\(y'
        End
    End

    Describe "SOH placeholder guard (collision prevention)"
        It "skips fix and warns when file contains raw SOH byte"
            printf '{"v": "has\x01soh"}' > test.json
            cp test.json expected.json
            When call fix_json_escapes test.json
            The status should be success
            The output should include "Warning"
            The output should include "raw control bytes"
            The contents of file "test.json" should equal "$(cat expected.json)"
        End
    End
End
