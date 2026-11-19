#!/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

eval "$(shellspec - -c) exit 1"

# Array containing files/directories to remove on test exit
cleanup=()
trap 'rm -rf "${cleanup[@]}"' EXIT

testdir() {
    testdir="$(mktemp -d)" && cleanup+=("${testdir}") && cd "${testdir}"
    AfterEach "rm -rf $testdir"
}

# Reproduce the JSON sanitization pipeline from the proccess-output step:
# 1. STONEINTG-1878 Go fmt artifact cleanup
# 2. STONEINTG-1899 invalid JSON escape sequence repair
fix_json_escapes() {
    local file="$1"
    sed -E -i 's/%!(.)\(MISSING\)/%\1/g; s/%!\(NOVERB\)/%/g' "$file"
    sed -i 's/\\\\/\x01/g' "$file"
    sed -E -i 's/\\([^"\\\/bfnrtu])/\\\\\1/g' "$file"
    sed -i 's/\x01/\\\\/g' "$file"
}

Describe "roxctl scan JSON escape sanitization"
    BeforeEach testdir

    Describe "invalid escape repair (STONEINTG-1899)"
        It "fixes backslash-paren that breaks jq"
            printf '{"summary": "foo\\(bar)"}' > test.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal '{"summary": "foo\\(bar)"}'
        End

        It "fixes backslash-bracket sequences"
            printf '{"path": "a\\[0\\]"}' > test.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal '{"path": "a\\[0\\]"}'
        End

        It "fixes multiple invalid escapes in one value"
            printf '{"v": "a\\(b\\)c\\[d\\]"}' > test.json
            When call fix_json_escapes test.json
            The status should be success
            The contents of file "test.json" should equal '{"v": "a\\(b\\)c\\[d\\]"}'
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
            # Three backslashes + paren: \\\ + ( = valid-pair \\ + invalid \(
            printf '{"v": "x\\\\\\(y"}' > test.json
            fix_json_escapes test.json
            When call jq -r '.v' test.json
            The status should be success
            The output should equal 'x\\(y'
        End
    End
End