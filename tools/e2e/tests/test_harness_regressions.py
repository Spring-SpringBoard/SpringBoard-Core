import tempfile
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from control.client import Control
from control.errors import ConnectionClosedError
from PIL import Image

from e2e.cli_e2e import _case_batches, _run_case, _write_suite_report
from e2e.driver._commands import CommandLogMixin
from e2e.driver._input import InputMixin
from e2e.driver._report import artifact_link
from e2e.driver._session import rml_diagnostics
from e2e.driver.cases import E2E_FLAGS, Case
from e2e.driver.utils.screenshots import Screenshot, ScreenshotWorker
from e2e.fixtures.golden import differing_pixels
from e2e.suite_report import artifact_paths, load_timing, write_report


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


def test_cropped_screenshot_assertions_wait_for_final_dimensions() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        shot = Screenshot(
            name="cropped",
            bmp_path=root / "cropped.bmp",
            png_path=root / "cropped.png",
            crop="without-status",
        )
        Image.new("RGBA", (4, 4), (10, 20, 30, 255)).save(shot.bmp_path)
        worker = ScreenshotWorker()
        try:
            worker.submit(shot)
            source = worker.source(shot.png_path)
            with Image.open(source) as image:
                assert image.size == (4, 1)
        finally:
            worker.finish()


def test_rml_diagnostics_select_only_rmlui_warnings_and_errors() -> None:
    lines = [
        "Warning: ordinary engine warning",
        "Warning: [RmlUi] Could not find variable name 'types' in data model.",
        "Error: [RmlUi] Data model name 'file_dialog' already exists.",
        "Error: unrelated engine error",
    ]
    assert rml_diagnostics(lines) == lines[1:3]


def test_failed_finalization_is_reported_without_stopping_the_case_loop(monkeypatch: pytest.MonkeyPatch) -> None:
    case = Case(name="fixture", flags=E2E_FLAGS, scenario="fixture")
    runner = MagicMock()
    runner.run_md = Path("/tmp/fixture-run.md")
    runner.finish.side_effect = AssertionError("golden mismatch")
    created: list[tuple[Case, bool, bool]] = []

    def create(
        case: Case,
        *,
        update_golden: bool,
        stage_goldens: bool,
        artifact_parent: Path | None,
    ) -> MagicMock:
        assert artifact_parent is None
        created.append((case, update_golden, stage_goldens))
        return runner

    monkeypatch.setattr("e2e.cli_e2e.E2ERun", create)

    failed, returned_runner = _run_case(case, update_golden=False, stage_golden=False, keep_open=False)
    assert failed
    assert returned_runner is runner
    assert created == [(case, False, False)]
    runner.launch.assert_called_once()
    runner.run_scenario.assert_called_once()
    runner.stop.assert_called_once()
    runner.cleanup_write_dir.assert_called_once()


def test_finalization_timeout_is_reported_as_a_case_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    case = Case(name="fixture-timeout", flags=E2E_FLAGS, scenario="fixture")
    runner = MagicMock()
    runner.run_md = Path("/tmp/fixture-timeout-run.md")
    runner.finish.side_effect = TimeoutError("capture timed out")

    monkeypatch.setattr("e2e.cli_e2e.E2ERun", lambda *_args, **_kwargs: runner)

    failed, returned_runner = _run_case(case, update_golden=False, stage_golden=False, keep_open=False)

    assert failed
    assert returned_runner is runner
    runner.stop.assert_called_once()
    runner.cleanup_write_dir.assert_called_once()


def test_default_suite_shares_unmarked_cases_and_isolates_marked_cases() -> None:
    cases = [
        Case(name="shared-a", flags=E2E_FLAGS, scenario="synthetic-a"),
        Case(name="alternate-a", flags=E2E_FLAGS, scenario="synthetic-b", env={"TEST_ENV": "alternate"}),
        Case(name="marked", flags=E2E_FLAGS, scenario="synthetic-c", isolated=True),
        Case(name="shared-b", flags=E2E_FLAGS, scenario="synthetic-d"),
        Case(name="alternate-b", flags=E2E_FLAGS, scenario="synthetic-e", env={"TEST_ENV": "alternate"}),
    ]

    assert [[case.name for case in batch] for batch in _case_batches(cases, True)] == [
        ["shared-a", "shared-b"],
        ["alternate-a", "alternate-b"],
        ["marked"],
    ]
    assert [[case.name for case in batch] for batch in _case_batches(cases, False)] == [
        ["shared-a"],
        ["alternate-a"],
        ["marked"],
        ["shared-b"],
        ["alternate-b"],
    ]


def test_wait_for_command_defaults_to_the_current_case() -> None:
    probe = MagicMock()
    probe._command_base = 1
    probe.commands.return_value = [
        {"data": {"className": "ReloadIntoProjectCommand", "__cmd_id": 1}},
        {"data": {"className": "ReloadIntoProjectCommand", "__cmd_id": 2}},
    ]

    result = CommandLogMixin.wait_for_command(probe, "ReloadIntoProjectCommand")

    assert result["__cmd_id"] == 2


def test_reload_lifecycle_is_not_retried_after_socket_close(tmp_path: Path) -> None:
    class ClosedConnection:
        instance_id = "old-instance"

        def __init__(self) -> None:
            self.calls: list[str] = []

        def call(self, method: str, **_params: object) -> dict[str, object]:
            self.calls.append(method)
            raise ConnectionClosedError(0, "closed during reload")

        def close(self) -> None:
            pass

    connection = ClosedConnection()
    control = Control.__new__(Control)
    control._connection = connection
    control._write_dir = tmp_path
    reconnected: list[str] = []
    control._reconnect_after_native_reload = lambda instance_id, **_kwargs: reconnected.append(instance_id)

    control.reload_native_modules()

    assert connection.calls == ["runtime.reload_native_modules"]
    assert reconnected == ["old-instance"]


def test_run_report_artifacts_are_relative_markdown_links(tmp_path: Path) -> None:
    report_dir = tmp_path / "case"
    artifact = report_dir / "events.jsonl"

    assert artifact_link(artifact, report_dir) == "[events.jsonl](events.jsonl)"


def test_suite_report_breaks_down_timing_and_api_usage(tmp_path: Path) -> None:
    run = tmp_path / "20260730-120000-control"
    run.mkdir()
    run.joinpath("run.md").write_text("# case\n- artifacts: `case`\n")
    run.joinpath("events.jsonl").write_text("""\
{"kind":"launch","time":10}
{"kind":"ui_ready","time":14}
{"kind":"control_connected","time":15}
{"kind":"screenshot","elapsed_ms":20,"time":16}
{"kind":"screenshot_converted","elapsed_ms":40,"time":17}
{"kind":"assert_pixels_timed","elapsed_ms":30,"time":18}
{"kind":"finish","status":"complete","time":20}
{"kind":"teardown_complete","time":21}
""")
    timing = load_timing(run)
    assert timing.api == "control"
    assert (timing.boot_s, timing.scenario_s, timing.total_s) == (4, 6, 10)

    output = tmp_path / "summary.md"
    write_report([run], output)
    text = output.read_text()
    assert "- summed boot time: 4.0s" in text
    assert "- summed scenario time: 6.0s" in text
    assert "- summed screenshot capture time: 0.0s" in text
    assert "- summed image-conversion CPU time: 0.0s" in text
    assert "- summed image/golden assertion time: 0.0s" in text
    assert "- summed total time: 10.0s" in text
    assert (
        "| [control](20260730-120000-control/run.md) | control | complete | 4.0s | 6.0s | "
        "0.0s | 0.0s | 0.0s | 4.0s | 10.0s |"
    ) in text
    run_report = run.joinpath("run.md").read_text()
    assert "- suite report: [summary.md](../summary.md)" in run_report


def test_automatic_suite_report_is_colocated_with_the_first_run(tmp_path: Path) -> None:
    run = tmp_path / "20260730-120000-control"
    run.mkdir()
    run.joinpath("run.md").write_text("# case\n- artifacts: `case`\n")
    run.joinpath("events.jsonl").write_text(
        '{"kind":"launch","time":10}\n{"kind":"ui_ready","time":14}\n{"kind":"finish","status":"complete","time":20}\n'
    )
    runner = type("Runner", (), {"out_dir": run})()

    _write_suite_report("control", [(False, runner)])

    report = run / "suite-report.md"
    assert report.is_file()
    assert (
        "| [control](run.md) | none | complete | 4.0s | 6.0s | 0.0s | 0.0s | 0.0s | — | 10.0s |" in report.read_text()
    )
    assert "- suite report: [suite-report.md](suite-report.md)" in run.joinpath("run.md").read_text()


def test_grouped_suite_keeps_scenarios_and_report_under_one_directory(tmp_path: Path) -> None:
    suite = tmp_path / "20260730-120000-suite"
    first = suite / "first"
    second = suite / "second"
    for run, start in ((first, 10), (second, 20)):
        run.mkdir(parents=True)
        run.joinpath("run.md").write_text("# case\n- artifacts: `case`\n")
        run.joinpath("events.jsonl").write_text(
            f'{{"kind":"launch","time":{start}}}\n'
            f'{{"kind":"ui_ready","time":{start + 4}}}\n'
            f'{{"kind":"finish","status":"complete","time":{start + 10}}}\n'
        )

    first_runner = type("Runner", (), {"out_dir": first})()
    second_runner = type("Runner", (), {"out_dir": second})()
    _write_suite_report("all", [(False, first_runner), (False, second_runner)])

    report = suite / "suite-report.md"
    assert report.is_file()
    text = report.read_text()
    assert "[first](first/run.md)" in text
    assert "[second](second/run.md)" in text
    assert "- suite report: [suite-report.md](../suite-report.md)" in first.joinpath("run.md").read_text()
    assert "- suite report: [suite-report.md](../suite-report.md)" in second.joinpath("run.md").read_text()
    assert [path.relative_to(tmp_path) for path in artifact_paths(tmp_path)] == [
        Path("20260730-120000-suite/first"),
        Path("20260730-120000-suite/second"),
    ]
    assert load_timing(first).case == "first"
