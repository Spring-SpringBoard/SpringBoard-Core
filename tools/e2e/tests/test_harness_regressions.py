import tempfile
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from PIL import Image

from e2e.cli_e2e import _run_case
from e2e.driver._input import InputMixin
from e2e.driver._session import rml_diagnostics
from e2e.driver.cases import RUST_FLAGS, Case
from e2e.fixtures.golden import differing_pixels


def test_root_input_uses_the_window_origin(monkeypatch: pytest.MonkeyPatch) -> None:
    class Probe:
        window = "window-id"

        def require_window(self) -> None:
            return None

    monkeypatch.setattr("e2e.driver._input.window_geometry_values", lambda _window: {"X": 2560, "Y": 40})
    assert InputMixin._root_point(Probe(), 20, 30) == (2580, 70)


def test_one_channel_blend_noise_is_ignored_but_visible_change_is_not() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        expected = root / "expected.png"
        one_channel = root / "one-channel.png"
        visible = root / "visible.png"
        Image.new("RGBA", (1, 1), (10, 20, 30, 255)).save(expected)
        Image.new("RGBA", (1, 1), (11, 21, 31, 255)).save(one_channel)
        Image.new("RGBA", (1, 1), (12, 20, 30, 255)).save(visible)

        assert differing_pixels(expected, one_channel) == 0
        assert differing_pixels(expected, visible) == 1


def test_live_status_strip_can_be_excluded_from_a_full_frame_comparison() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        expected = root / "expected.png"
        live_status = root / "live-status.png"
        Image.new("RGBA", (2, 3), (10, 20, 30, 255)).save(expected)
        image = Image.new("RGBA", (2, 3), (10, 20, 30, 255))
        image.putpixel((1, 2), (50, 60, 70, 255))
        image.save(live_status)

        assert differing_pixels(expected, live_status) == 1
        assert differing_pixels(expected, live_status, ignored_bottom=1) == 0


def test_rml_diagnostics_select_only_rmlui_warnings_and_errors() -> None:
    lines = [
        "Warning: ordinary engine warning",
        "Warning: [RmlUi] Could not find variable name 'types' in data model.",
        "Error: [RmlUi] Data model name 'file_dialog' already exists.",
        "Error: unrelated engine error",
    ]
    assert rml_diagnostics(lines) == lines[1:3]


def test_failed_finalization_is_reported_without_stopping_the_case_loop(monkeypatch: pytest.MonkeyPatch) -> None:
    case = Case(name="fixture-rust", flags=RUST_FLAGS, scenario="fixture")
    runner = MagicMock()
    runner.run_md = Path("/tmp/fixture-run.md")
    runner.finish.side_effect = AssertionError("golden mismatch")
    created: list[tuple[Case, bool, bool]] = []

    def create(case: Case, *, update_golden: bool, stage_goldens: bool) -> MagicMock:
        created.append((case, update_golden, stage_goldens))
        return runner

    monkeypatch.setattr("e2e.cli_e2e.E2ERun", create)

    assert _run_case(case, update_golden=False, stage_golden=False, keep_open=False)
    assert created == [(case, False, False)]
    runner.launch.assert_called_once()
    runner.run_scenario.assert_called_once()
    runner.stop.assert_called_once()
    runner.cleanup_write_dir.assert_called_once()
