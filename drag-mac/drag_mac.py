"""drag-mac: a macOS drag source for ranger's `dn` binding.

Replaces dragon-drop (X11-only) on Darwin. See PLAN.md.

Phase 1 scope: show a window that survives a detached launch. The drag itself
lands in Phase 3.

Two hard constraints drive the design:

  1. Nothing may read stdin. A detached launch has no terminal on stdin, so any
     blocking read returns EOF immediately. That is precisely how the previous
     candidate tool self-terminated in ~130ms without ever becoming visible.
  2. Every ObjC object that outlives its creating scope must be held by a strong
     Python reference (see _RETAIN). Premature garbage collection of a bridged
     object is the classic PyObjC crash, and is the adapted form of Power-of-10
     rule 9.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from AppKit import (
    NSApplication,
    NSApplicationActivationPolicyAccessory,
    NSBackingStoreBuffered,
    NSColor,
    NSEvent,
    NSFloatingWindowLevel,
    NSMakeRect,
    NSPanel,
    NSTextField,
    NSWindowStyleMaskClosable,
    NSWindowStyleMaskNonactivatingPanel,
    NSWindowStyleMaskTitled,
)
from Foundation import NSTimer

EXIT_OK = 0
EXIT_BAD_TARGET = 1
EXIT_USAGE = 2

DEFAULT_TIMEOUT_S = 120.0
TIMEOUT_ENV_VAR = "DRAG_MAC_TIMEOUT_S"

PANEL_WIDTH = 168.0
PANEL_HEIGHT = 96.0

# Rule 9: strong references to every bridged object that outlives its creating
# scope. Never read for logic, only to keep objects alive. Cleared at terminate.
_RETAIN: dict[str, object] = {}


class UsageError(Exception):
    """Wrong number or shape of arguments."""


class TargetError(Exception):
    """A path that cannot be dragged."""


def require(condition: object, message: str, exc: type[Exception] = ValueError) -> None:
    """Contract check. Rule 5 deliberately avoids bare `assert`, which python -O
    strips, silently voiding every contract in the module."""
    if not condition:
        raise exc(message)


def read_timeout(environ: dict[str, str] | None = None) -> float:
    """Watchdog interval. Rule 2: an unused window must not linger forever."""
    env = os.environ if environ is None else environ
    raw = env.get(TIMEOUT_ENV_VAR)
    if raw is None:
        return DEFAULT_TIMEOUT_S
    try:
        value = float(raw)
    except ValueError:
        return DEFAULT_TIMEOUT_S
    if value <= 0:
        return DEFAULT_TIMEOUT_S
    return value


def resolve_targets(args: list[str], cwd: str | None = None) -> list[Path]:
    """Validate and absolutise every path up front.

    Rule 3: all validation happens before the window is shown, so no allocation
    or failure can occur inside a drag callback. Phase 2 expands the test
    coverage here.
    """
    require(isinstance(args, list), "args must be a list", TypeError)
    require(args, "no files given", UsageError)

    base = Path(cwd) if cwd else Path(os.environ.get("PWD", os.getcwd()))
    resolved: list[Path] = []
    seen: set[str] = set()

    for raw in args:
        require(isinstance(raw, str), f"path must be a string, got {type(raw)}", TypeError)
        expanded = Path(raw).expanduser()
        target = expanded if expanded.is_absolute() else base / expanded
        if not target.exists():
            raise TargetError(f"does not exist: {target}")
        key = str(target)
        if key in seen:
            continue
        seen.add(key)
        resolved.append(target)

    require(resolved, "no usable targets", UsageError)
    return resolved


def label_for(targets: list[Path]) -> str:
    """Panel caption."""
    require(isinstance(targets, list), "targets must be a list", TypeError)
    require(targets, "cannot label an empty selection", UsageError)
    if len(targets) == 1:
        return targets[0].name
    return f"{len(targets)} items"


def build_panel(caption: str) -> NSPanel:
    """A small floating panel placed near the pointer."""
    require(isinstance(caption, str), "caption must be a string", TypeError)
    require(caption, "caption must not be empty", ValueError)

    style = (
        NSWindowStyleMaskNonactivatingPanel
        | NSWindowStyleMaskTitled
        | NSWindowStyleMaskClosable
    )
    panel = NSPanel.alloc().initWithContentRect_styleMask_backing_defer_(
        NSMakeRect(0.0, 0.0, PANEL_WIDTH, PANEL_HEIGHT), style, NSBackingStoreBuffered, False
    )
    require(panel is not None, "NSPanel allocation returned nil", RuntimeError)

    panel.setTitle_("drag")
    panel.setTitlebarAppearsTransparent_(True)
    panel.setLevel_(NSFloatingWindowLevel)
    panel.setFloatingPanel_(True)
    panel.setHidesOnDeactivate_(False)
    panel.setReleasedWhenClosed_(False)
    panel.setBackgroundColor_(NSColor.windowBackgroundColor())

    field = NSTextField.alloc().initWithFrame_(
        NSMakeRect(8.0, 8.0, PANEL_WIDTH - 16.0, PANEL_HEIGHT - 40.0)
    )
    require(field is not None, "NSTextField allocation returned nil", RuntimeError)
    field.setStringValue_(caption)
    field.setEditable_(False)
    field.setSelectable_(False)
    field.setBordered_(False)
    field.setDrawsBackground_(False)
    field.setAlignment_(1)  # NSTextAlignmentCenter
    panel.contentView().addSubview_(field)
    _RETAIN["caption_field"] = field

    _place_near_pointer(panel)
    return panel


def _place_near_pointer(panel: NSPanel) -> None:
    """Position near the mouse, the way dragon-drop does, but clamped on screen."""
    location = NSEvent.mouseLocation()
    screen = panel.screen()
    x = location.x - PANEL_WIDTH / 2.0
    y = location.y

    if screen is not None:
        frame = screen.visibleFrame()
        x = max(frame.origin.x, min(x, frame.origin.x + frame.size.width - PANEL_WIDTH))
        y = max(frame.origin.y + PANEL_HEIGHT, min(y, frame.origin.y + frame.size.height))

    panel.setFrameTopLeftPoint_((x, y))


def schedule_watchdog(timeout_s: float) -> None:
    """Terminate after timeout_s if nothing happened. Rule 2."""
    require(isinstance(timeout_s, float), "timeout must be a float", TypeError)
    require(timeout_s > 0, "timeout must be positive", ValueError)

    def fire(_timer: object) -> None:
        finish(EXIT_OK)

    timer = NSTimer.scheduledTimerWithTimeInterval_repeats_block_(timeout_s, False, fire)
    require(timer is not None, "scheduling the watchdog returned nil", RuntimeError)
    _RETAIN["watchdog"] = timer
    _RETAIN["watchdog_block"] = fire


def finish(code: int) -> None:
    """Single exit path. Nothing here reads stdin, by construction."""
    require(isinstance(code, int), "exit code must be an int", TypeError)
    require(code >= 0, "exit code must be non-negative", ValueError)
    app = _RETAIN.get("app")
    _RETAIN.clear()

    if app is None:
        sys.exit(code)

    # Inside the runloop sys.exit does not work: PyObjC traps the SystemExit
    # raised in an ObjC callback, logs it, and the loop keeps spinning. AppKit's
    # own terminate_ is the real exit, and it tears the window down cleanly.
    # It always exits 0, which is correct for every in-runloop exit we have
    # (watchdog fired, drag completed). Failures all happen before app.run().
    if code == EXIT_OK:
        app.terminate_(None)
        return
    os._exit(code)


def main(argv: list[str]) -> int:
    require(isinstance(argv, list), "argv must be a list", TypeError)
    require(argv, "argv must include the program name", ValueError)

    try:
        targets = resolve_targets(argv[1:])
    except UsageError as exc:
        print(f"usage: drag-mac FILE [FILE...]\n{exc}", file=sys.stderr)
        return EXIT_USAGE
    except TargetError as exc:
        print(f"drag-mac: {exc}", file=sys.stderr)
        return EXIT_BAD_TARGET

    app = NSApplication.sharedApplication()
    require(app is not None, "sharedApplication returned nil", RuntimeError)
    _RETAIN["app"] = app

    # Accessory, not regular: no Dock icon, no menu bar takeover, but still
    # allowed to put a window on screen. A .prohibited policy would prevent the
    # window from ever appearing.
    app.setActivationPolicy_(NSApplicationActivationPolicyAccessory)

    panel = build_panel(label_for(targets))
    _RETAIN["panel"] = panel
    _RETAIN["targets"] = targets

    panel.makeKeyAndOrderFront_(None)
    app.activateIgnoringOtherApps_(True)

    schedule_watchdog(read_timeout())
    app.run()
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main(sys.argv))
