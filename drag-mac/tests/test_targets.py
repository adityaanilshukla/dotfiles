"""Tier 1: pure logic. No GUI, no subprocess, runs anywhere.

Audits the path/label/timeout code that Phase 1 needed early. Cases are the
list in PLAN.md section 5.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from drag_mac import (  # noqa: E402
    EXIT_BAD_TARGET,
    EXIT_OK,
    EXIT_USAGE,
    TargetError,
    UsageError,
    label_for,
    main,
    read_timeout,
    require,
    resolve_targets,
)


class TestResolveTargets:
    def test_no_arguments_is_a_usage_error(self):
        with pytest.raises(UsageError):
            resolve_targets([])

    def test_nonexistent_path_is_a_target_error(self, tmp_path):
        with pytest.raises(TargetError):
            resolve_targets([str(tmp_path / "nope.txt")])

    def test_absolute_path_passes_through(self, tmp_path):
        f = tmp_path / "a.txt"
        f.write_text("x")
        assert resolve_targets([str(f)]) == [f]

    def test_relative_path_resolves_against_cwd(self, tmp_path):
        f = tmp_path / "rel.txt"
        f.write_text("x")
        assert resolve_targets(["rel.txt"], cwd=str(tmp_path)) == [f]

    def test_tilde_expands_to_home(self):
        # ~ must expand; the home directory itself always exists.
        assert resolve_targets(["~"]) == [Path.home()]

    def test_directory_is_a_valid_target(self, tmp_path):
        assert resolve_targets([str(tmp_path)]) == [tmp_path]

    def test_broken_symlink_is_rejected(self, tmp_path):
        link = tmp_path / "dangling"
        link.symlink_to(tmp_path / "missing-target")
        with pytest.raises(TargetError):
            resolve_targets([str(link)])

    def test_intact_symlink_is_accepted(self, tmp_path):
        real = tmp_path / "real.txt"
        real.write_text("x")
        link = tmp_path / "link.txt"
        link.symlink_to(real)
        assert resolve_targets([str(link)]) == [link]

    @pytest.mark.parametrize(
        "name",
        [
            "with space.txt",
            "unicode-éè中文.txt",
            "with'quote.txt",
            "with\"doublequote.txt",
            "with;semicolon.txt",
            "with$dollar.txt",
            "-leading-dash.txt",
        ],
    )
    def test_awkward_filenames_survive_intact(self, tmp_path, name):
        f = tmp_path / name
        f.write_text("x")
        assert resolve_targets([str(f)]) == [f]

    def test_newline_in_filename_survives(self, tmp_path):
        f = tmp_path / "with\nnewline.txt"
        f.write_text("x")
        assert resolve_targets([str(f)]) == [f]

    def test_duplicates_are_collapsed_preserving_order(self, tmp_path):
        a = tmp_path / "a.txt"
        b = tmp_path / "b.txt"
        a.write_text("x")
        b.write_text("x")
        assert resolve_targets([str(a), str(b), str(a)]) == [a, b]

    def test_order_is_preserved(self, tmp_path):
        names = ["c.txt", "a.txt", "b.txt"]
        for n in names:
            (tmp_path / n).write_text("x")
        got = resolve_targets([str(tmp_path / n) for n in names])
        assert [p.name for p in got] == names

    def test_one_bad_path_rejects_the_whole_selection(self, tmp_path):
        """Rule 3: validate everything up front. A partial drag would be worse
        than a clear failure."""
        good = tmp_path / "good.txt"
        good.write_text("x")
        with pytest.raises(TargetError):
            resolve_targets([str(good), str(tmp_path / "bad.txt")])

    def test_non_list_argument_is_a_type_error(self):
        with pytest.raises(TypeError):
            resolve_targets("not-a-list")  # type: ignore[arg-type]

    def test_non_string_element_is_a_type_error(self):
        with pytest.raises(TypeError):
            resolve_targets([123])  # type: ignore[list-item]


class TestLabelFor:
    def test_single_file_uses_basename(self, tmp_path):
        assert label_for([tmp_path / "report.pdf"]) == "report.pdf"

    def test_multiple_files_are_counted(self, tmp_path):
        targets = [tmp_path / f"{i}.txt" for i in range(3)]
        assert label_for(targets) == "3 items"

    def test_two_files_are_counted(self, tmp_path):
        assert label_for([tmp_path / "a", tmp_path / "b"]) == "2 items"

    def test_empty_selection_is_rejected(self):
        with pytest.raises(UsageError):
            label_for([])

    def test_non_list_is_a_type_error(self):
        with pytest.raises(TypeError):
            label_for("nope")  # type: ignore[arg-type]


class TestReadTimeout:
    def test_default_when_unset(self):
        assert read_timeout({}) == 120.0

    def test_reads_the_env_var(self):
        assert read_timeout({"DRAG_MAC_TIMEOUT_S": "5"}) == 5.0

    def test_garbage_falls_back_to_default(self):
        assert read_timeout({"DRAG_MAC_TIMEOUT_S": "banana"}) == 120.0

    def test_zero_falls_back_to_default(self):
        """A zero timeout would fire the watchdog instantly and the window would
        never be usable."""
        assert read_timeout({"DRAG_MAC_TIMEOUT_S": "0"}) == 120.0

    def test_negative_falls_back_to_default(self):
        assert read_timeout({"DRAG_MAC_TIMEOUT_S": "-3"}) == 120.0

    def test_float_is_accepted(self):
        assert read_timeout({"DRAG_MAC_TIMEOUT_S": "1.5"}) == 1.5


class TestRequire:
    def test_passes_silently_when_true(self):
        require(True, "should not raise")

    def test_raises_the_requested_type(self):
        with pytest.raises(TypeError):
            require(False, "boom", TypeError)

    def test_defaults_to_value_error(self):
        with pytest.raises(ValueError):
            require(False, "boom")

    def test_message_is_preserved(self):
        with pytest.raises(ValueError, match="specific message"):
            require(False, "specific message")

    def test_is_not_stripped_under_optimisation(self):
        """Rule 5: bare `assert` vanishes under python -O, silently voiding
        every contract. require() must survive."""
        import subprocess

        code = (
            "import sys; sys.path.insert(0, %r);"
            "from drag_mac import require;"
            "require(False, 'still enforced')" % str(Path(__file__).resolve().parent.parent)
        )
        result = subprocess.run(
            [sys.executable, "-O", "-c", code], capture_output=True, text=True
        )
        assert result.returncode != 0, "require() was stripped under -O"
        assert "still enforced" in result.stderr


class TestExitCodes:
    def test_codes_are_distinct(self):
        assert len({EXIT_OK, EXIT_BAD_TARGET, EXIT_USAGE}) == 3

    def test_ok_is_zero(self):
        assert EXIT_OK == 0

    def test_main_with_no_files_returns_usage(self, capsys):
        assert main(["drag-mac"]) == EXIT_USAGE

    def test_main_with_missing_file_returns_bad_target(self, tmp_path, capsys):
        assert main(["drag-mac", str(tmp_path / "nope.txt")]) == EXIT_BAD_TARGET

    def test_main_rejects_empty_argv(self):
        with pytest.raises(ValueError):
            main([])
