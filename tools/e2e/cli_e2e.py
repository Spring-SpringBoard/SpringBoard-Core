import json
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated, cast

import typer

from .driver.cases import TARGETS, Case, select_cases, target_cases
from .driver.utils.paths import ARTIFACT_ROOT, create_suite_artifact_dir
from .fixtures.golden import (
    GOLDEN_ROOT,
    STATUS_APPROVED,
    approve_review,
    differing_pixels,
    golden_path,
    load_review,
    write_diff,
)
from .runner import E2ERun
from .suite_report import artifact_paths, default_report_path, write_report

app = typer.Typer(no_args_is_help=True)


@dataclass
class SharedSession:
    """One process shared by the default resettable scenario group."""

    owner: E2ERun | None = None
    camera_baseline: dict[str, object] | None = None

    def attach(self, runner: E2ERun) -> None:
        if self.owner is None:
            self.owner = runner
            runner.launch()
            self.camera_baseline = runner.control.camera.get()
            return
        runner.reuse_session(self.owner)
        undone = runner.control.reset_session()
        runner.event("session_reset", strategy="undo-reload", undone=undone)
        self._restore_camera(runner)

    def close(self) -> None:
        if self.owner is not None:
            self.owner.stop()
            self.owner.cleanup_write_dir()

    def _restore_camera(self, runner: E2ERun) -> None:
        state = self.camera_baseline
        if state is None:
            return
        controller_position = cast("list[float]", state["controller_position"])
        direction = cast("list[float]", state["direction"])
        height = float(state["height"])
        angle = float(state["angle"])
        distance = float(state["distance"])
        runner.control.camera.set(
            controller_position=controller_position,
            direction=direction,
            fov=float(state["fov"]),
            height=height if height > 0.0 else None,
            angle=angle if angle > 0.0 else None,
            distance=distance if distance > 0.0 else None,
        )
        runner.control.wait_for_update()
        runner.event(
            "camera_reset",
            fields=["controller_position", "direction", "fov", "height", "angle", "distance"],
        )


@app.command()
def run(
    target: Annotated[str, typer.Argument(help="Scenario target or 'all'.")],
    tag: Annotated[list[str] | None, typer.Option(help="Require a case tag.")] = None,
    update_golden: Annotated[bool, typer.Option(help="Write new golden references.")] = False,
    stage_golden: Annotated[bool, typer.Option(help="Capture without updating goldens.")] = False,
    keep_open: Annotated[bool, typer.Option(help="Keep the editor and write directory after the run.")] = False,
) -> None:
    tags = tag or []
    cases = _select_run_cases(target, tags, update_golden, stage_golden)
    artifact_parent = create_suite_artifact_dir() if len(cases) > 1 else None
    results = _run_batches(
        cases,
        update_golden=update_golden,
        stage_golden=stage_golden,
        keep_open=keep_open,
        reuse_sessions=not keep_open,
        artifact_parent=artifact_parent,
    )
    _write_suite_report(target, results)
    if any(failed for failed, _runner in results):
        raise typer.Exit(1)


@app.command()
def report(
    after: Annotated[str | None, typer.Option(help="Inclusive UTC artifact timestamp, YYYYMMDD-HHMMSS.")] = None,
    before: Annotated[str | None, typer.Option(help="Inclusive UTC artifact timestamp, YYYYMMDD-HHMMSS.")] = None,
    output: Annotated[
        Path | None,
        typer.Option(help="Report path; default creates one under the artifact root."),
    ] = None,
) -> None:
    """Write a timing/API summary from existing artifacts; does not launch Spring."""
    paths = artifact_paths(ARTIFACT_ROOT, after=after, before=before)
    if not paths:
        raise typer.BadParameter("no run artifacts match the requested range")
    destination = output or default_report_path(ARTIFACT_ROOT)
    write_report(paths, destination)
    typer.echo(f"suite report: {destination}")


@app.command("goldens-status")
def goldens_status() -> None:
    pending = 0
    for case_dir in sorted(GOLDEN_ROOT.iterdir()):
        if not case_dir.is_dir():
            continue
        review = load_review(case_dir.name)
        shots = sorted(path.stem for path in case_dir.glob("*.png"))
        approved = sum(shot in review and review[shot]["status"] == STATUS_APPROVED for shot in shots)
        pending += len(shots) - approved
        typer.echo(f"{case_dir.name:26} {approved}/{len(shots)} approved")
        for shot in shots:
            if shot not in review or review[shot]["status"] != STATUS_APPROVED:
                typer.echo(f"    ai-reviewed  {shot}")
    if pending:
        typer.echo(f"\n{pending} image(s) awaiting approval.")


@app.command("goldens-diff")
def goldens_diff(
    case: Annotated[str, typer.Argument(help="Golden case directory.")],
    run: Annotated[Path | None, typer.Option(help="Run directory; default is the latest for the case.")] = None,
    out: Annotated[Path | None, typer.Option(help="Where to write the overlays.")] = None,
) -> None:
    """Show where a case's captures differ from its goldens, as magenta overlays.

    Reports every shot, including the ones whose difference stays inside their
    tolerance -- those are invisible in a run, and they are exactly what you want
    to see before deciding whether a golden is stale.
    """
    run_dir = run or _latest_run_dir(case)
    if run_dir is None:
        raise typer.BadParameter(f"no run artifacts for {case}; run `just test-e2e {case}` first")
    checks = _golden_checks(run_dir)
    if not checks:
        raise typer.BadParameter(f"{run_dir} recorded no goldens")
    destination = out or run_dir / "golden-diffs"
    destination.mkdir(parents=True, exist_ok=True)
    if any("ignored_bottom" not in check for check in checks.values()):
        typer.echo(
            f"warning: {run_dir.name} predates recorded golden metadata, so the "
            "ignored status strip and each shot's tolerance are unknown here; "
            "counts include regions the run itself does not read. Re-run the case."
        )
    for name, check in sorted(checks.items()):
        actual = Path(check["path"])
        golden = golden_path(case, name)
        if not actual.is_file() or not golden.is_file():
            typer.echo(f"{name:32} missing capture or golden")
            continue
        ignored_bottom = int(check.get("ignored_bottom", 0))
        channel_tolerance = int(check.get("channel_tolerance", 1))
        tolerance = int(check.get("tolerance", 0))
        differing = differing_pixels(
            golden,
            actual,
            channel_tolerance=channel_tolerance,
            ignored_bottom=ignored_bottom,
        )
        if not differing:
            typer.echo(f"{name:32} identical")
            continue
        target = destination / f"{name}.diff.png"
        write_diff(
            golden,
            actual,
            target,
            channel_tolerance=channel_tolerance,
            ignored_bottom=ignored_bottom,
        )
        verdict = "over tolerance" if differing > tolerance else f"within tolerance {tolerance}"
        typer.echo(f"{name:32} {differing:>8} px  {verdict:<22} {target}")
    typer.echo(f"\ndiffs: {destination}")


@app.command("approve-goldens")
def approve_goldens(
    case: Annotated[str, typer.Argument(help="Golden case directory.")],
    shots: Annotated[list[str] | None, typer.Argument(help="Optional screenshot names.")] = None,
) -> None:
    approved = approve_review(case, set(shots or ()))
    typer.echo(f"approved {approved} image(s) for {case}")


def _select_run_cases(
    target: str,
    tags: list[str],
    update_golden: bool,
    stage_golden: bool,
) -> list[Case]:
    if target != "all" and target not in TARGETS:
        raise typer.BadParameter(f"unknown target {target!r}; choose one of: {', '.join(TARGETS)}")
    if update_golden and stage_golden:
        raise typer.BadParameter("--update-golden and --stage-golden are mutually exclusive")
    cases = select_cases([target], tags) if tags or target == "all" else target_cases(target)
    if not cases:
        raise typer.BadParameter(f"no cases match target={target!r}, tags={tags!r}")
    return cases


def _run_batches(
    cases: list[Case],
    *,
    update_golden: bool,
    stage_golden: bool,
    keep_open: bool,
    reuse_sessions: bool,
    artifact_parent: Path | None,
) -> list[tuple[bool, E2ERun]]:
    results: list[tuple[bool, E2ERun]] = []
    for batch in _case_batches(cases, reuse_sessions):
        shared = SharedSession() if len(batch) > 1 else None
        try:
            results.extend(
                _run_case(
                    case,
                    update_golden=update_golden,
                    stage_golden=stage_golden,
                    keep_open=keep_open,
                    shared_session=shared,
                    artifact_parent=artifact_parent,
                )
                for case in batch
            )
        finally:
            if shared is not None:
                shared.close()
    return results


def _write_suite_report(target: str, results: list[tuple[bool, E2ERun]]) -> None:
    if not results:
        return
    # A grouped run has a suite directory containing each scenario directory;
    # a focused run keeps the summary beside its sole scenario.
    first_run = results[0][1].out_dir
    report = first_run.parent / "suite-report.md" if len(results) > 1 else first_run / "suite-report.md"
    write_report((runner.out_dir for _failed, runner in results), report, title=f"UI E2E: {target}")
    typer.echo(f"suite report: {report}")


def _run_case(
    case: Case,
    *,
    update_golden: bool,
    stage_golden: bool,
    keep_open: bool,
    shared_session: SharedSession | None = None,
    artifact_parent: Path | None = None,
) -> tuple[bool, E2ERun]:
    runner = E2ERun(
        case,
        update_golden=update_golden,
        stage_goldens=stage_golden,
        artifact_parent=artifact_parent,
    )
    typer.echo(f"run.md: {runner.run_md}")
    scenario_error: Exception | None = None
    try:
        if shared_session is None:
            runner.launch()
        else:
            shared_session.attach(runner)
        runner.run_scenario()
    except Exception as error:
        scenario_error = error
        runner.event("error", error=_error_message(error))
    try:
        extra = {"error": _error_message(scenario_error)} if scenario_error else {}
        runner.finish("failed" if scenario_error else "complete", **extra)
    except Exception as error:
        # Finalization includes captures, image conversion, diagnostics, and
        # assertions. Any ordinary failure belongs to this case, not the suite.
        if scenario_error is None:
            runner.event("error", error=_error_message(error))
        typer.echo(f"ERROR: {case.name}: {_error_message(error)}", err=True)
        return True, runner
    finally:
        if shared_session is not None:
            runner.close_control()
        elif not keep_open:
            runner.stop()
            runner.cleanup_write_dir()
        typer.echo(f"run.md: {runner.run_md}")
    if scenario_error is not None:
        typer.echo(f"ERROR: {case.name}: {_error_message(scenario_error)}", err=True)
        return True, runner
    return False, runner


def _error_message(error: Exception) -> str:
    return str(error) or error.__class__.__name__


def _case_batches(cases: list[Case], reuse_sessions: bool) -> Iterator[list[Case]]:
    """Share compatible launch environments; isolate only marked cases."""
    emitted: set[tuple[tuple[tuple[str, str], ...], tuple[tuple[str, str], ...]]] = set()
    for case in cases:
        if case.isolated or not reuse_sessions:
            yield [case]
            continue
        key = _batch_key(case)
        if key in emitted:
            continue
        emitted.add(key)
        yield [candidate for candidate in cases if not candidate.isolated and _batch_key(candidate) == key]


def _batch_key(case: Case) -> tuple[tuple[tuple[str, str], ...], tuple[tuple[str, str], ...]]:
    return tuple(sorted(case.flags.items())), tuple(sorted(case.env.items()))


def _latest_run_dir(case: str) -> Path | None:
    """The newest artifact directory holding this case, standalone or in a suite."""
    if not ARTIFACT_ROOT.is_dir():
        return None
    candidates = [path for path in ARTIFACT_ROOT.glob(f"*-{case}") if path.is_dir()]
    candidates += [path / case for path in ARTIFACT_ROOT.glob("*-suite") if (path / case).is_dir()]
    return max(candidates, key=lambda path: path.stat().st_mtime, default=None)


def _golden_checks(run_dir: Path) -> dict[str, dict[str, object]]:
    """The `golden` events of a run, newest entry per shot."""
    events = run_dir / "events.jsonl"
    if not events.is_file():
        return {}
    checks: dict[str, dict[str, object]] = {}
    for line in events.read_text().splitlines():
        try:
            event = cast("dict[str, object]", json.loads(line))
        except json.JSONDecodeError:
            continue
        if event.get("kind") == "golden" and isinstance(event.get("name"), str):
            checks[cast("str", event["name"])] = event
    return checks
