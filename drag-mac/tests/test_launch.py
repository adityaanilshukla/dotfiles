"""Tier 2: process and window integration. Needs a login GUI session.

These are the Phase 1 go/no-go gate from PLAN.md. They are written before any
implementation exists and are expected to fail until drag_mac.py can show a
window under a detached launch. If they cannot be made green inside the phase
budget, the plan says stop and fall back to Yoink.
"""

from __future__ import annotations

import pytest

from conftest import poll_until

pytestmark = pytest.mark.gui


def windows_for_pid(pid: int) -> list[dict]:
    """On-screen windows owned by pid.

    Deliberately reads only kCGWindowOwnerPID / kCGWindowBounds /
    kCGWindowIsOnscreen. kCGWindowName is avoided because it requires Screen
    Recording permission on modern macOS and would make this test a permissions
    test rather than a visibility test.
    """
    import Quartz

    info = Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID
    )
    return [w for w in info if w.get("kCGWindowOwnerPID") == pid]


def test_survives_detached_launch(spawn_tool, sample_file):
    """Regression test for the bug that killed jannis-baum/drag.

    That tool blocked on getchar(), got EOF immediately because a detached
    process has no terminal on stdin, and self-terminated in ~130ms. Any exit
    path that depends on stdin reintroduces the bug and fails here.
    """
    tool = spawn_tool(str(sample_file))

    exited = tool.wait_for_exit(timeout_s=3.0)

    assert exited is None, (
        f"process exited with code {exited} within 3s of a detached launch; "
        f"it must stay alive waiting for a drag. Output:\n{tool.output()}"
    )
    assert tool.alive()


def test_window_becomes_visible(spawn_tool, sample_file):
    """The unretired risk from PLAN.md section 3: can a non-bundled process
    actually put a window on screen when launched detached?"""
    tool = spawn_tool(str(sample_file))

    found = poll_until(lambda: windows_for_pid(tool.pid) or None)

    assert found, (
        f"no on-screen window owned by pid {tool.pid} appeared. "
        f"alive={tool.alive()}. Output:\n{tool.output()}"
    )

    bounds = found[0].get("kCGWindowBounds", {})
    assert bounds.get("Width", 0) > 0, f"window has zero width: {bounds}"
    assert bounds.get("Height", 0) > 0, f"window has zero height: {bounds}"


def test_exactly_one_window(spawn_tool, sample_file):
    tool = spawn_tool(str(sample_file))

    found = poll_until(lambda: windows_for_pid(tool.pid) or None)

    assert found, "no window appeared at all"
    assert len(found) == 1, f"expected exactly 1 window, got {len(found)}: {found}"


def test_survives_idle(spawn_tool, sample_file):
    """Catches Rule 9 regressions: a bridged ObjC object getting garbage
    collected out from under the window after creation."""
    tool = spawn_tool(str(sample_file))

    assert poll_until(lambda: windows_for_pid(tool.pid) or None), "window never appeared"

    assert tool.wait_for_exit(timeout_s=5.0) is None, (
        f"process died while idle. Output:\n{tool.output()}"
    )
    assert windows_for_pid(tool.pid), "window vanished while idle (premature GC?)"


def test_watchdog_exit(spawn_tool, sample_file):
    """Rule 2: an unused window must not linger forever."""
    tool = spawn_tool(str(sample_file), env_overrides={"DRAG_MAC_TIMEOUT_S": "2"})

    code = tool.wait_for_exit(timeout_s=8.0)

    assert code is not None, "watchdog did not fire; process still running"
    assert code == 0, f"watchdog exit should be clean, got {code}. Output:\n{tool.output()}"


def test_sigterm_is_clean(spawn_tool, sample_file):
    tool = spawn_tool(str(sample_file))

    assert poll_until(lambda: windows_for_pid(tool.pid) or None), "window never appeared"

    tool.terminate()

    assert not tool.alive()
    assert not windows_for_pid(tool.pid), "window outlived the process"
