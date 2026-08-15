# drag-mac build plan

A macOS drag source for ranger's `dn` binding. Replaces `dragon-drop` (X11-only) on
Darwin. Written in Python against AppKit via PyObjC.

## 1. Objective and scope

`dn` in ranger must: take the current selection (N files), pop up a small floating
window, let the user drag it into any GUI app, then get out of the way.

Parity targets, taken from the existing Linux invocation
`dragon-drop -a -x -- file1 file2 ...`:

| Behaviour | dragon-drop flag | drag-mac requirement |
|---|---|---|
| All selected files as one drag | `-a` | One `NSDraggingSession` carrying N `NSDraggingItem`s |
| Exit after one completed drop | `-x` | `draggingSession:endedAt:operation:` terminates the app |
| Never blocks the caller | `setsid -f` in `commands.py` | Must survive a detached launch with no controlling terminal |

Out of scope: drag *into* ranger, persistent shelf behaviour, any GUI beyond one panel.

## 2. Why Python is viable here

An earlier advisor pass rejected JXA for this job, correctly: System Events cannot
create a drag source, and implementing `NSDraggingSource` delegate methods through
the JXA bridge is impractical. PyObjC is a different bridge with different
capability. It supports real ObjC protocol conformance and delegate method
implementation, so `NSView.mouseDown_`, `beginDraggingSessionWithItems_event_source_`
and the `NSDraggingSource` callbacks are all reachable from Python. That rejection
does not transfer to PyObjC.

Tradeoffs accepted by choosing Python over Swift:

- Not a self-contained binary. Needs PyObjC present at runtime, so install becomes a
  venv step rather than a copied executable.
- Slower cold start (roughly 200 to 400ms interpreter plus framework import, versus
  roughly 50ms for a compiled binary). Acceptable for a popup triggered by hand.
- Homebrew's python3 is PEP 668 externally managed. `pip3 install --user` was already
  observed to fail this session. A dedicated venv is therefore mandatory, not optional.

## 3. Risk register

| Risk | Status | Mitigation |
|---|---|---|
| A non-bundled process cannot show a window when launched detached | **RETIRED.** Accessory activation policy plus activate is enough; no `.app` bundle needed. Confirmed by test and by eye. | Phase 1 gate, passed |
| Premature garbage collection of bridged ObjC objects | Held off so far | Adapted Rule 9, plus an idle-survival test |
| TCC blocks reading files in Desktop/Documents | Still open | Manual acceptance case 12; the interpreter inherits the caller's TCC identity |
| `kCGWindowName` needs Screen Recording permission | Confirmed avoidable | Tests assert on owner PID and bounds, never on window title |

### Things that only turned up by building it

- **macOS ships no `setsid(1)`.** It is a util-linux tool. The Darwin path has
  to detach with `start_new_session=True`, the `setsid(2)` syscall itself.
- **`sys.exit()` does nothing inside a runloop callback.** PyObjC traps the
  `SystemExit`, logs it, and the loop keeps spinning. AppKit's `terminate_` is
  the real exit. A watchdog written the obvious way would have hung forever.
- **`NSDraggingContextOutsideApplication` is 0, not 1.** Hardcoding it inverted
  made every external drop silently impossible while the drag still lifted and
  tracked normally. The unit test asserted the same wrong literal and passed
  throughout. Caught only by Tier 3. Constants now come from AppKit, never from
  memory.
- **`xcodebuild` needs full Xcode, `swiftc` does not.** Irrelevant once the
  language choice moved to Python, but it is why the earlier Swift attempt
  stalled.

The previous tool (`jannis-baum/drag`) failed because it called `getchar()` on stdin
and terminated on EOF. Under a detached launch stdin is not a terminal, EOF is
immediate, and it self-terminated in about 130ms. **No stdin-dependent exit path may
appear anywhere in this tool.** Phase 1 encodes that as a regression test.

## 4. Ruleset: NASA Power of 10, adapted

The original targets embedded C. Rules 3, 8 and 9 are translated rather than dropped.

| # | Original | Adapted | Enforced by |
|---|---|---|---|
| 1 | No goto, no recursion | No recursion, no `exec`/`eval`, no monkey-patching, no metaclasses. Straight-line control flow. | ruff, review |
| 2 | Loops need fixed bounds | Every poll or wait loop carries an explicit iteration cap and a deadline. The app itself has a hard watchdog auto-exit (default 120s) so an unused window can never linger forever. | review, test |
| 3 | No heap allocation after init | Resolve and validate every path, and build every item provider, *before* the window is shown. No allocation inside drag callbacks. | review |
| 4 | Functions fit one page | Functions at most 60 lines, one job each. Whole module under 250 lines. | ruff, review |
| 5 | Two or more assertions per function | Two or more contract checks per public function, via an explicit `require()` that raises. Never bare `assert`, which `python -O` strips. | review, one test per raise path |
| 6 | Smallest data scope | No module-level mutable state except the documented strong-reference registry from Rule 9. Everything else passed explicitly. | ruff, review |
| 7 | Check every return value | Every PyObjC call that can return nil is checked before use. No bare `except`. | mypy, review |
| 8 | Sparing preprocessor use | No dynamic imports, no import-time side effects, no non-stdlib decorators. | ruff |
| 9 | One pointer dereference, no function pointers | Hold an explicit strong Python reference to every ObjC object outliving its creating scope (app, panel, view, drag items). Premature GC of a bridged object is the classic PyObjC crash. One documented registry, cleared only at terminate. | review, idle-survival test |
| 10 | All warnings on, static analysis clean | `python -W error`, ruff clean, `mypy --strict` clean, pytest run with `-W error`. | `make check` |

## 5. Test strategy

Automated coverage stops where the mouse begins. Stating that honestly up front so the
green checkmarks are not mistaken for proof the feature works.

### Tier 1: pure logic, no GUI, runs anywhere (`tests/test_targets.py`)

Real TDD, fast, deterministic.

- no arguments raises usage error, exit code 2
- nonexistent path raises target error, exit code 1
- relative path resolves against `PWD` to an absolute path
- `~/file` expands to the home directory
- filenames containing spaces, unicode, and newlines survive intact
- duplicate paths preserve input order, deduplicated
- a directory is a valid target
- a broken symlink is rejected
- label is the basename for one file, and "N items" for many
- exit codes are a documented enum, not scattered integer literals

### Tier 2: process and window integration, needs a login GUI session (`tests/test_launch.py`, marked `gui`)

- **`test_survives_detached_launch`**: spawn via `setsid` with stdin at `/dev/null`,
  assert the process is still alive after 3 seconds. This is the regression test for
  the exact bug that killed the previous tool. It is written first, before any
  implementation exists.
- **`test_window_becomes_visible`**: poll `CGWindowListCopyWindowInfo` for a window
  owned by the child PID within a bounded number of attempts. Assert onscreen and
  non-zero bounds. Never asserts on title, which needs Screen Recording permission.
- `test_exactly_one_window`
- `test_watchdog_exit`: with the timeout overridden low by env var, assert clean exit 0
- `test_sigterm_is_clean`: no orphan process, no crash report
- `test_survives_idle`: still alive and window still present after N seconds, catching
  Rule 9 GC regressions

### Tier 3: manual acceptance, human required (`ACCEPTANCE.md`)

Not automatable. A synthetic mouse drag is possible via CGEvent but is flaky enough
that it would cost more than it proves.

- launch from ranger via `dn`; window appears above the ranger pane
- drag into Finder; file lands
- drag into a browser upload field; file uploads
- select 3 files; all 3 arrive at the destination
- window closes on its own after the drop
- Escape closes without dropping
- a file in `~/Documents` works, or the TCC prompt is understood

## 6. Phases, ordered by risk retired per minute

**Phase 0, environment gate (~20 min).** Create the venv, install PyObjC, confirm
Quartz window enumeration works at all, get `make test` running and reporting zero
tests. Exit: the harness runs.

**Phase 1, the go/no-go gate (~40 min).** Write `test_survives_detached_launch` and
`test_window_becomes_visible` first and watch them fail. Then write the smallest
possible window module until both go green: `NSApplication`, accessory activation
policy, floating `NSPanel`, `NSApp.activate`, no stdin anywhere. **If these cannot be
made green inside the budget, stop and fall back to Yoink.** Everything downstream
assumes this gate passed.

**Phase 2, pure logic (~20 min).** Tier 1 tests, then the path and label
implementation. Ordinary TDD.

**Phase 3, the drag itself (~30 min).** `mouseDown_` starting the session with N
items, the source operation mask, and `draggingSession:endedAt:operation:` calling
terminate. Unit-test what is reachable (provider construction, mask value, terminate
called on the ended callback with a faked session). The drop itself moves to Tier 3.

**Phase 4, integration (~20 min).** Platform guard in `ranger/commands.py` so Linux
keeps using `dragon-drop` untouched and Darwin uses `drag-mac`, with an accurate
per-platform notify message. Wire `install.sh`. Write `ACCEPTANCE.md`.

**Phase 5.** Run the Tier 3 checklist by hand. Only then is this done.

## 7. Layout and install

```
dotfiles/
  drag-mac/
    PLAN.md
    ACCEPTANCE.md          manual checklist
    Makefile               venv, test, check, install
    drag_mac.py            the tool, importable so tests can reach it
    tests/
      conftest.py
      test_targets.py      tier 1
      test_launch.py       tier 2, marked gui
  scripts/
    drag-mac               three-line sh wrapper, execs the venv python
```

The venv lives at `~/.local/share/drag-mac/venv`, created by `install.sh`, following
the same "build it into a known location" pattern already used for online-zathura.
`scripts/drag-mac` gets symlinked to `~/.local/bin/drag-mac`, which is on PATH as of
commit 5a0ec68.

## 8. Exit criteria

Done means: Tier 1 and Tier 2 green, `make check` clean under Rule 10, the Tier 3
checklist passed by hand, `dn` works in a ranger launched from the aerospace `alt-n`
binding, and Linux behaviour is provably unchanged.

Total budget 2 hours, with the Phase 1 gate at roughly 40 minutes. Blowing the Phase 1
budget means buying Yoink and wiring `dn` to `open -a Yoink -- <files>` instead. The
fallback is Yoink, never a fork of the abandoned or the unlicensed tool.

## 9. Branching

This work does not belong on `fix/notification-dismiss-and-path`. Cut `feat/drag-mac`
from `MacOS` before Phase 0. One commit per phase, tests in the same commit as the
code they cover.
