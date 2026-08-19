"""Compact timing and API-use reports for one or more E2E run artifacts."""

import json
import os
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

INPUT_EVENTS = frozenset(
    {
        "click",
        "click_root",
        "click_settled",
        "drag",
        "key",
        "key_chord",
        "move",
        "move_relative",
        "press",
        "release",
        "type",
        "wheel",
        "wheel_root",
    }
)


@dataclass(frozen=True)
class RunTiming:
    path: Path
    case: str
    status: str
    api: str
    boot_s: float | None
    scenario_s: float | None
    capture_s: float | None
    image_cpu_s: float | None
    assertion_s: float | None
    post_capture_s: float | None
    teardown_s: float | None
    total_s: float | None
    started_at: float | None
    error: str | None


def load_timing(path: Path) -> RunTiming:
    """Read one immutable run artifact without needing a live engine session."""
    events_path = path / "events.jsonl"
    events = [json.loads(line) for line in events_path.read_text().splitlines() if line.strip()]
    by_kind: dict[str, list[dict[str, object]]] = {}
    for event in events:
        by_kind.setdefault(str(event["kind"]), []).append(event)

    def event_time(kind: str, last: bool = False) -> float | None:
        matches = by_kind.get(kind, [])
        if not matches:
            return None
        return float(matches[-1 if last else 0]["time"])

    launch = event_time("launch") or event_time("session_reused")
    ready = event_time("ui_ready") or launch
    finish = event_time("finish", last=True)
    capture_events = [
        event for kind in ("screenshot", "screenshot_root", "control_capture") for event in by_kind.get(kind, [])
    ]
    conversion_events = by_kind.get("screenshot_converted", [])
    pixel_events = by_kind.get("assert_pixels_timed", [])
    golden_events = by_kind.get("golden", [])
    last_capture = max((float(event["time"]) for event in capture_events), default=None)
    has_control = "control_connected" in by_kind
    has_input = bool(INPUT_EVENTS.intersection(by_kind))
    if has_control and has_input:
        api = "control + input"
    elif has_control:
        api = "control"
    elif has_input:
        api = "input"
    else:
        api = "none"
    finish_event = (by_kind.get("finish") or [{}])[-1]
    error_event = (by_kind.get("error") or [{}])[-1]
    fallback_case = path.name if not path.name[:8].isdigit() else path.name.split("-", 2)[-1]
    return RunTiming(
        path=path,
        case=str(finish_event.get("case", fallback_case)),
        status=str(finish_event.get("status", "incomplete")),
        api=api,
        boot_s=_elapsed(launch, ready),
        scenario_s=_elapsed(ready, finish),
        capture_s=_sum_ms(capture_events, "elapsed_ms"),
        image_cpu_s=_sum_ms(conversion_events, "elapsed_ms"),
        assertion_s=_sum_ms(pixel_events, "elapsed_ms") + _sum_ms(golden_events, "compare_ms"),
        post_capture_s=_elapsed(last_capture, finish),
        teardown_s=_elapsed(event_time("teardown_start"), event_time("teardown_complete")),
        total_s=_elapsed(launch, finish),
        started_at=launch,
        error=str(error_event["error"]) if "error" in error_event else None,
    )


def artifact_paths(root: Path, *, after: str | None = None, before: str | None = None) -> list[Path]:
    """Find standalone and grouped case artifacts in a timestamp range."""
    paths = []
    for events_path in root.glob("**/events.jsonl"):
        path = events_path.parent
        if not path.is_dir():
            continue
        stamp = path.name[:15] if path.name[:8].isdigit() else path.parent.name[:15]
        if after is not None and stamp < after:
            continue
        if before is not None and stamp > before:
            continue
        paths.append(path)
    return sorted(paths)


def write_report(paths: Iterable[Path], output: Path, *, title: str = "UI E2E suite") -> list[RunTiming]:
    timings = sorted((load_timing(path) for path in paths), key=lambda timing: (timing.started_at or 0, timing.case))
    summed_boot_s = sum(timing.boot_s or 0.0 for timing in timings)
    summed_scenario_s = sum(timing.scenario_s or 0.0 for timing in timings)
    summed_capture_s = sum(timing.capture_s or 0.0 for timing in timings)
    summed_image_cpu_s = sum(timing.image_cpu_s or 0.0 for timing in timings)
    summed_assertion_s = sum(timing.assertion_s or 0.0 for timing in timings)
    summed_post_capture_s = sum(timing.post_capture_s or 0.0 for timing in timings)
    summed_teardown_s = sum(timing.teardown_s or 0.0 for timing in timings)
    summed_case_s = sum(timing.total_s or 0.0 for timing in timings)
    started = [timing.started_at for timing in timings if timing.started_at is not None]
    ended = [
        timing.started_at + timing.total_s for timing in timings if timing.started_at is not None and timing.total_s
    ]
    suite_wall_s = max(ended) - min(started) if started and ended else None
    passed = sum(timing.status == "complete" for timing in timings)
    failed = len(timings) - passed
    lines = [
        f"# {title}",
        "",
        f"- cases: {len(timings)} ({passed} complete, {failed} failed/incomplete)",
        f"- suite wall time: {_format_seconds(suite_wall_s)}",
        f"- summed boot time: {_format_seconds(summed_boot_s)}",
        f"- summed scenario time: {_format_seconds(summed_scenario_s)}",
        f"- summed screenshot capture time: {_format_seconds(summed_capture_s)}",
        f"- summed image-conversion CPU time: {_format_seconds(summed_image_cpu_s)}",
        f"- summed image/golden assertion time: {_format_seconds(summed_assertion_s)}",
        f"- summed post-capture tail: {_format_seconds(summed_post_capture_s)}",
        f"- summed teardown time: {_format_seconds(summed_teardown_s)}",
        f"- summed total time: {_format_seconds(summed_case_s)}",
        "- timing: boot = engine launch to UI-ready; scenario = UI-ready to finish; "
        "image CPU is the sum of parallel worker time.",
        "- API: `input` uses X11 mouse/keyboard events; `control` uses the typed control channel.",
        "",
        "| Case | API | Status | Boot | Scenario | Capture | Image CPU | Assert | Tail | Total |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    lines.extend(_table_row(timing, output.parent) for timing in timings)
    failures = [timing for timing in timings if timing.status != "complete"]
    if failures:
        lines += ["", "## Failures", ""]
        for timing in failures:
            detail = timing.error or "No error event recorded."
            lines.append(f"- `{timing.case}`: {detail}")
    output.write_text("\n".join(lines) + "\n")
    for timing in timings:
        _link_run_to_suite(timing.path / "run.md", output)
    return timings


def default_report_path(root: Path) -> Path:
    stamp = datetime.now(UTC).strftime("%Y%m%d-%H%M%S")
    return root / f"{stamp}-suite-report.md"


def _elapsed(start: float | None, end: float | None) -> float | None:
    return None if start is None or end is None else max(0.0, end - start)


def _sum_ms(events: Iterable[dict[str, object]], key: str) -> float:
    return sum(float(event.get(key, 0)) for event in events) / 1000.0


def _format_seconds(value: float | None) -> str:
    if value is None:
        return "—"
    if value >= 60:
        minutes, seconds = divmod(value, 60)
        return f"{int(minutes)}m {seconds:04.1f}s"
    return f"{value:.1f}s"


def _table_row(timing: RunTiming, report_root: Path) -> str:
    run_report = timing.path / "run.md"
    case = f"[{timing.case}]({_relative_target(run_report, report_root)})" if run_report.is_file() else timing.case
    cells = (
        case,
        timing.api,
        timing.status,
        _format_seconds(timing.boot_s),
        _format_seconds(timing.scenario_s),
        _format_seconds(timing.capture_s),
        _format_seconds(timing.image_cpu_s),
        _format_seconds(timing.assertion_s),
        _format_seconds(timing.post_capture_s),
        _format_seconds(timing.total_s),
    )
    return "| " + " | ".join(cells) + " |"


def _relative_target(path: Path, root: Path) -> str:
    return Path(os.path.relpath(path, root)).as_posix()


def _link_run_to_suite(run_report: Path, suite_report: Path) -> None:
    if not run_report.is_file():
        return
    link = f"- suite report: [{suite_report.name}]({_relative_target(suite_report, run_report.parent)})"
    lines = run_report.read_text().splitlines()
    _replace_suite_link(lines, link)
    run_report.write_text("\n".join(lines) + "\n")


def _replace_suite_link(lines: list[str], link: str) -> None:
    marker = "- suite report:"
    for index, line in enumerate(lines):
        if line.startswith(marker):
            lines[index] = link
            break
    else:
        insert_at = next(
            (index + 1 for index, line in enumerate(lines) if line.startswith("- artifacts:")),
            0,
        )
        lines.insert(insert_at, link)
