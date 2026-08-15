"""Tier 2: the launcher wrapper, which is what ranger actually executes.

drag_mac.py can be perfect while the wrapper is broken, so the shim gets its
own coverage: a wrong venv path or a moved module would only ever surface as
`dn` silently doing nothing.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

from conftest import poll_until
from test_launch import windows_for_pid

WRAPPER = Path(__file__).resolve().parent.parent.parent / "scripts" / "drag-mac"


def test_wrapper_exists_and_is_executable():
    assert WRAPPER.is_file(), f"missing wrapper at {WRAPPER}"
    assert os.access(WRAPPER, os.X_OK), "wrapper is not executable"


def test_wrapper_reports_usage_without_arguments():
    result = subprocess.run([str(WRAPPER)], capture_output=True, text=True, timeout=30)
    assert result.returncode == 2, f"expected usage exit 2, got {result.returncode}"


def test_wrapper_rejects_a_missing_file(tmp_path):
    result = subprocess.run(
        [str(WRAPPER), str(tmp_path / "nope.txt")],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode == 1, f"expected bad-target exit 1, got {result.returncode}"


def test_wrapper_fails_loudly_when_the_venv_is_missing(tmp_path, sample_file):
    """A missing venv must not look like success. Silent failure here would be
    indistinguishable from `dn` being unbound."""
    env = os.environ.copy()
    env["DRAG_MAC_VENV"] = str(tmp_path / "definitely-not-here")

    result = subprocess.run(
        [str(WRAPPER), str(sample_file)],
        capture_output=True,
        text=True,
        env=env,
        timeout=30,
    )

    assert result.returncode == 127
    assert "venv missing" in result.stderr


@pytest.mark.gui
def test_wrapper_opens_a_window(sample_file):
    """End-to-end through the real entry point, detached the way ranger does."""
    proc = subprocess.Popen(
        [str(WRAPPER), str(sample_file)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        env={**os.environ, "DRAG_MAC_TIMEOUT_S": "20"},
    )
    try:
        # The wrapper execs python in place, so the window belongs to this pid.
        found = poll_until(lambda: windows_for_pid(proc.pid) or None)
        assert found, "wrapper produced no window"
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
