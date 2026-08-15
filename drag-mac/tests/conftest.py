"""Shared fixtures for the drag-mac suite. Test tiers are defined in PLAN.md
section 5.

The spawn helper here is the single source of truth for *how* the tool gets
launched, and it deliberately replicates ranger's real invocation:

  - start_new_session=True, which calls setsid(2) directly. macOS does not ship
    the setsid(1) binary that the Linux dragon-drop path shells out to, so this
    is the portable equivalent and is what commands.py must use on Darwin.
  - stdin at /dev/null. This is the condition that killed the previous tool
    (jannis-baum/drag): it blocked on getchar(), read EOF immediately, and
    terminated itself in ~130ms. Any regression back into a stdin-dependent
    exit path must fail test_survives_detached_launch.
"""

from __future__ import annotations

import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
TOOL = REPO_ROOT / "drag_mac.py"

# Rule 2: every wait loop carries an explicit cap and a deadline.
POLL_INTERVAL_S = 0.1
POLL_MAX_ATTEMPTS = 100


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line(
        "markers", "gui: Tier 2. Spawns real windows; needs a login GUI session."
    )


@pytest.fixture
def sample_file(tmp_path: Path) -> Path:
    target = tmp_path / "sample.txt"
    target.write_text("drag me\n")
    return target


class SpawnedTool:
    """A detached drag-mac process, guaranteed to be reaped by the fixture."""

    def __init__(self, proc: subprocess.Popen[bytes]) -> None:
        self.proc = proc

    @property
    def pid(self) -> int:
        return self.proc.pid

    def alive(self) -> bool:
        return self.proc.poll() is None

    def wait_for_exit(self, timeout_s: float) -> int | None:
        try:
            return self.proc.wait(timeout=timeout_s)
        except subprocess.TimeoutExpired:
            return None

    def output(self) -> str:
        """Best-effort captured output; only valid once the process has exited."""
        if self.proc.stdout is None:
            return ""
        try:
            return self.proc.stdout.read().decode("utf-8", "replace")
        except (ValueError, OSError):
            return ""

    def terminate(self) -> None:
        if not self.alive():
            return
        self.proc.send_signal(signal.SIGTERM)
        if self.wait_for_exit(2.0) is None:
            self.proc.kill()
            self.proc.wait(timeout=2.0)


@pytest.fixture
def spawn_tool():
    """Launch drag-mac exactly the way ranger will: detached, stdin closed."""
    spawned: list[SpawnedTool] = []

    def _spawn(*args: str, env_overrides: dict[str, str] | None = None) -> SpawnedTool:
        import os

        env = os.environ.copy()
        if env_overrides:
            env.update(env_overrides)
        proc = subprocess.Popen(
            [sys.executable, str(TOOL), *args],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            env=env,
        )
        handle = SpawnedTool(proc)
        spawned.append(handle)
        return handle

    yield _spawn

    for handle in spawned:
        handle.terminate()


def poll_until(predicate, *, max_attempts: int = POLL_MAX_ATTEMPTS,
               interval_s: float = POLL_INTERVAL_S):
    """Bounded poll (Rule 2). Returns the first truthy result, or None."""
    for _ in range(max_attempts):
        result = predicate()
        if result:
            return result
        time.sleep(interval_s)
    return None
