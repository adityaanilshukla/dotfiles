"""Phase 3: the drag source itself.

These construct real AppKit objects but never open a window or spin a runloop,
so they are Tier 1 (no `gui` marker). The actual mouse drag and drop is not
automatable and lives in ACCEPTANCE.md.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from drag_mac import (  # noqa: E402
    DragSourceView,
    build_dragging_items,
    drag_payload,
)


@pytest.fixture
def two_files(tmp_path):
    a = tmp_path / "one.txt"
    b = tmp_path / "two.txt"
    a.write_text("a")
    b.write_text("b")
    return [a, b]


class TestDragPayload:
    def test_one_url_per_target(self, two_files):
        payload = drag_payload(two_files)
        assert len(payload) == 2

    def test_urls_are_file_urls_pointing_at_the_targets(self, two_files):
        payload = drag_payload(two_files)
        assert [url.path() for url, _icon in payload] == [str(p) for p in two_files]

    def test_every_target_gets_an_icon(self, two_files):
        payload = drag_payload(two_files)
        for _url, icon in payload:
            assert icon is not None

    def test_url_is_recognised_as_a_pasteboard_writer(self, two_files):
        """If NSURL stopped conforming to NSPasteboardWriting the drag would
        produce an empty pasteboard and silently drop nothing."""
        payload = drag_payload(two_files)
        url, _icon = payload[0]
        assert url.writableTypesForPasteboard_(None)

    def test_empty_selection_is_rejected(self):
        with pytest.raises(Exception):
            drag_payload([])

    def test_non_list_is_a_type_error(self):
        with pytest.raises(TypeError):
            drag_payload("nope")


class TestBuildDraggingItems:
    def test_one_item_per_target(self, two_files):
        items = build_dragging_items(drag_payload(two_files))
        assert len(items) == 2

    def test_items_have_non_zero_frames(self, two_files):
        """A zero-size dragging frame produces an invisible drag image."""
        items = build_dragging_items(drag_payload(two_files))
        for item in items:
            frame = item.draggingFrame()
            assert frame.size.width > 0
            assert frame.size.height > 0

    def test_items_are_offset_so_a_stack_is_visible(self, two_files):
        items = build_dragging_items(drag_payload(two_files))
        origins = [(i.draggingFrame().origin.x, i.draggingFrame().origin.y) for i in items]
        assert len(set(origins)) == len(origins), f"items overlap exactly: {origins}"

    def test_empty_payload_is_rejected(self):
        with pytest.raises(Exception):
            build_dragging_items([])


class TestDragSourceView:
    def test_view_conforms_to_the_dragging_source_protocol(self):
        """PyObjC only routes the delegate callbacks if conformance is declared.
        Without it the session would never report that it ended and the tool
        would hang until the watchdog."""
        import objc

        assert DragSourceView.conformsToProtocol_(objc.protocolNamed("NSDraggingSource"))

    def test_reports_copy_for_an_outside_drag(self, two_files):
        """Regression: this asserted against a hardcoded 1 and passed while the
        code was broken, because both used the same inverted guess at the
        context constant. Dragging into another app is context 0, and the tool
        was answering NSDragOperationNone to exactly that, so no browser or
        chat window would accept the drop. Always assert against the real
        AppKit constant, never a literal.
        """
        from AppKit import NSDragOperationCopy, NSDraggingContextOutsideApplication

        view = DragSourceView.alloc().initWithTargets_(two_files)
        mask = view.draggingSession_sourceOperationMaskForDraggingContext_(
            None, NSDraggingContextOutsideApplication
        )
        assert mask == NSDragOperationCopy

    def test_outside_application_context_is_zero(self):
        """Pins the constant the bug got backwards."""
        from AppKit import (
            NSDraggingContextOutsideApplication,
            NSDraggingContextWithinApplication,
        )

        assert NSDraggingContextOutsideApplication == 0
        assert NSDraggingContextWithinApplication == 1

    def test_never_reports_none_for_any_context(self, two_files):
        """A None mask is silently fatal: the drag still lifts and tracks, so it
        looks healthy, but nothing can accept it."""
        from AppKit import (
            NSDragOperationNone,
            NSDraggingContextOutsideApplication,
            NSDraggingContextWithinApplication,
        )

        view = DragSourceView.alloc().initWithTargets_(two_files)
        for context in (
            NSDraggingContextOutsideApplication,
            NSDraggingContextWithinApplication,
        ):
            mask = view.draggingSession_sourceOperationMaskForDraggingContext_(None, context)
            assert mask != NSDragOperationNone, f"context {context} refuses every drop"

    def test_a_completed_drop_finishes(self, two_files, monkeypatch):
        view = DragSourceView.alloc().initWithTargets_(two_files)
        calls = []
        monkeypatch.setattr("drag_mac.finish", lambda code: calls.append(code))

        from AppKit import NSDragOperationCopy

        view.draggingSession_endedAt_operation_(None, (0, 0), NSDragOperationCopy)

        assert calls == [0], "a completed drop must exit, matching dragon-drop -x"

    def test_a_cancelled_drag_does_not_finish(self, two_files, monkeypatch):
        """Deliberate divergence from dragon-drop: a fumbled drag leaves the
        window up rather than forcing a relaunch. The watchdog still bounds it."""
        from AppKit import NSDragOperationNone

        view = DragSourceView.alloc().initWithTargets_(two_files)
        calls = []
        monkeypatch.setattr("drag_mac.finish", lambda code: calls.append(code))

        view.draggingSession_endedAt_operation_(None, (0, 0), NSDragOperationNone)

        assert calls == []

    def test_view_retains_its_targets(self, two_files):
        view = DragSourceView.alloc().initWithTargets_(two_files)
        assert list(view.targets()) == two_files


def key_event(characters: str, key_code: int):
    """A synthetic key-down, so keyboard exits are testable without a human."""
    from AppKit import NSEvent, NSKeyDown

    return NSEvent.keyEventWithType_location_modifierFlags_timestamp_windowNumber_context_characters_charactersIgnoringModifiers_isARepeat_keyCode_(
        NSKeyDown, (0.0, 0.0), 0, 0.0, 0, None, characters, characters, False, key_code
    )


class TestKeyboardExit:
    """The window has to be dismissable without touching the mouse."""

    ESCAPE = ("\x1b", 53)

    def test_escape_closes_the_window(self, two_files, monkeypatch):
        view = DragSourceView.alloc().initWithTargets_(two_files)
        calls = []
        monkeypatch.setattr("drag_mac.finish", lambda c: calls.append(c))

        view.keyDown_(key_event(*self.ESCAPE))

        assert calls == [0]

    @pytest.mark.parametrize("chars,code", [("q", 12), ("Q", 12), ("z", 6), ("d", 2)])
    def test_letters_never_close_the_window(self, two_files, monkeypatch, chars, code):
        """q must not close this window.

        A keystroke only reaches here when the panel really has focus. The
        hazard is believing it does when ranger does instead, where q quits
        ranger outright. Escape is the only safe key to train the hand on, so
        it is the only one bound. Dismissing without focus is the aerospace
        binding's job.
        """
        view = DragSourceView.alloc().initWithTargets_(two_files)
        calls = []
        monkeypatch.setattr("drag_mac.finish", lambda c: calls.append(c))

        view.keyDown_(key_event(chars, code))

        assert calls == [], f"{chars!r} must not close the window"

    def test_cancel_operation_closes(self, two_files, monkeypatch):
        """Escape also arrives as cancelOperation_ on some paths."""
        view = DragSourceView.alloc().initWithTargets_(two_files)
        calls = []
        monkeypatch.setattr("drag_mac.finish", lambda c: calls.append(c))

        view.cancelOperation_(None)

        assert calls == [0]


class TestResponderWiring:
    def test_the_drag_view_is_first_responder(self, two_files):
        """Regression: the panel itself was first responder, so cancelOperation_
        on the view was never reachable and Escape did nothing. The responder
        chain runs view -> window, not window -> view.
        """
        from drag_mac import build_panel

        panel = build_panel(two_files)
        assert panel.firstResponder() is panel.contentView()

    def test_panel_can_become_key(self, two_files):
        """A panel that cannot become key receives no keystrokes at all."""
        from drag_mac import build_panel

        panel = build_panel(two_files)
        assert panel.canBecomeKeyWindow()
