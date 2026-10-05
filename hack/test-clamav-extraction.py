#!/usr/bin/python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise the extraction failure gate from both task YAML scripts."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap

repo = Path(__file__).resolve().parents[1]
for task in ("clamav-scan", "clamav-scan-min"):
    source = (repo / "task" / task / "0.3" / f"{task}.yaml").read_text()
    functions = re.search(
        r'(?ms)^([ ]+)extract_archives_serial\(\).*?(?=^\1case "\$ARCHIVE_EXTRACTION_MODE")',
        source,
    ).group()
    gate = re.search(
        r'(?ms)^ +if ! extract_archives "\$\{destination\}".*?^ +fi$',
        source,
    ).group()
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        binaries = root / "bin"
        binaries.mkdir()
        # Recognize a fixture archive; optionally fail while extracting it.
        (binaries / "bsdtar").write_text(
            '#!/bin/bash\n'
            'if [[ $1 == -tf ]]; then [[ $2 == *.archive ]] && echo payload; '
            'elif [[ $FAIL_EXTRACTION == 1 ]]; then exit 1; '
            'else echo payload > "$4/payload"; fi\n'
        )
        (binaries / "clamav-extract-archives").write_text("#!/bin/bash\nexit 23\n")
        for binary in binaries.iterdir():
            binary.chmod(0o755)
        script = (
            "set -euo pipefail\n"
            + textwrap.dedent(functions)
            + '\ndestination=$1\nsuffix=test\n'
            + textwrap.dedent(gate).replace("/work/logs/", temporary + "/")
            + '\nprintf scanned > "$2"\n'
        )
        for mode in ("legacy", "accelerated"):
            for failure in ("0", "1"):
                fixture = root / f"{mode}-{failure}"
                fixture.mkdir()
                archive = fixture / "input.archive"
                archive.write_text("fixture")
                scanned = fixture / "scanned"
                result = subprocess.run(
                    ["bash", "-c", script, "_", str(fixture), str(scanned)],
                    env=dict(os.environ, PATH=str(binaries) + ":" + os.environ["PATH"],
                             ARCHIVE_EXTRACTION_MODE=mode, MAX_THREADS="2",
                             FAIL_EXTRACTION=failure),
                    capture_output=True, text=True,
                )
                assert (result.returncode != 0) == (failure == "1"), result.stderr
                assert scanned.exists() == (failure == "0"), result.stderr
                assert archive.exists() == (failure == "1"), result.stderr
                if failure == "1":
                    assert "archive extraction incomplete" in result.stderr
        # A collision must stop both legacy mode and accelerated-mode fallback.
        for mode in ("legacy", "accelerated"):
            for kind in ("directory", "file", "symlink"):
                fixture = root / f"{mode}-collision-{kind}"
                fixture.mkdir()
                archive = fixture / "input.archive"
                archive.write_text("original archive")
                output = fixture / "input.archive.d"
                if kind == "directory":
                    output.mkdir()
                    (output / "marker").write_text("existing content")
                elif kind == "file":
                    output.write_text("existing content")
                else:
                    output.symlink_to("missing-target")
                scanned = fixture / "scanned"
                result = subprocess.run(
                    ["bash", "-c", script, "_", str(fixture), str(scanned)],
                    env=dict(os.environ, PATH=str(binaries) + ":" + os.environ["PATH"],
                             ARCHIVE_EXTRACTION_MODE=mode, MAX_THREADS="2",
                             FAIL_EXTRACTION="0"),
                    capture_output=True, text=True,
                )
                assert result.returncode != 0, result.stderr
                assert not scanned.exists()
                assert archive.read_text() == "original archive"
                assert "cannot create extraction output" in result.stdout, result.stdout
                assert "archive extraction incomplete" in result.stderr
                if kind == "directory":
                    assert list(output.iterdir()) == [output / "marker"]
                    assert (output / "marker").read_text() == "existing content"
                elif kind == "file":
                    assert output.read_text() == "existing content"
                else:
                    assert output.is_symlink()
                    assert os.readlink(output) == "missing-target"
    print(f"PASS: {task} successful fallback, failure gate, and output collisions")
