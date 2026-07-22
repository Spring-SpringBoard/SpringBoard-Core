from typing import Annotated

import typer

from .driver.cases import TARGETS, select_cases, target_cases
from .driver.utils.golden import GOLDEN_ROOT, STATUS_APPROVED, approve_review, load_review
from .runner import E2ERun

app = typer.Typer(no_args_is_help=True)


@app.command()
def run(
    target: Annotated[str, typer.Argument(help="Scenario target or 'all'.")] = "chonsole",
    tag: Annotated[list[str] | None, typer.Option(help="Require a case tag.")] = None,
    update_golden: Annotated[bool, typer.Option(help="Write new golden references.")] = False,
    stage_golden: Annotated[bool, typer.Option(help="Capture without updating goldens.")] = False,
    keep_open: Annotated[bool, typer.Option(help="Keep the editor and write directory after the run.")] = False,
) -> None:
    tags = tag or []
    if target != "all" and target not in TARGETS:
        raise typer.BadParameter(f"unknown target {target!r}; choose one of: {', '.join(TARGETS)}")
    if update_golden and stage_golden:
        raise typer.BadParameter("--update-golden and --stage-golden are mutually exclusive")
    cases = select_cases([target], tags) if tags or target == "all" else target_cases(target)
    if not cases:
        raise typer.BadParameter(f"no cases match target={target!r}, tags={tags!r}")
    failures = 0
    for case in cases:
        runner = E2ERun(
            case,
            update_golden=update_golden,
            stage_goldens=stage_golden,
        )
        typer.echo(f"run.md: {runner.run_md}")
        try:
            runner.launch()
            runner.run_scenario()
            runner.finish("complete")
        except Exception as error:
            failures += 1
            runner.event("error", error=str(error))
            runner.finish("failed", error=str(error))
            typer.echo(f"ERROR: {case.name}: {error}", err=True)
        finally:
            if not keep_open:
                runner.stop()
                runner.cleanup_write_dir()
            typer.echo(f"run.md: {runner.run_md}")
    if failures:
        raise typer.Exit(1)


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


@app.command("approve-goldens")
def approve_goldens(
    case: Annotated[str, typer.Argument(help="Golden case directory.")],
    shots: Annotated[list[str] | None, typer.Argument(help="Optional screenshot names.")] = None,
) -> None:
    approved = approve_review(case, set(shots or ()))
    typer.echo(f"approved {approved} image(s) for {case}")
