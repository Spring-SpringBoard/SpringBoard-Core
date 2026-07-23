from pathlib import Path
from typing import Annotated

import typer

from .engine import boot, launch_manual
from .integration_runner import run_tests

app = typer.Typer(no_args_is_help=True)


@app.command()
def boot_editor() -> None:
    typer.echo(boot(tags=["__startup_only__"]))


@app.command()
def bench_save_image() -> None:
    output = run_tests(tags=["save_image_bench"])
    report = output.write_dir / "save-image-bench" / "report.json"
    typer.echo(f"artifacts: {output.write_dir}")
    if report.is_file():
        typer.echo(report.read_text())
    failed = [result for result in output.results["results"] if not result["passed"]]
    if failed:
        messages = "; ".join(f"{result['name']}: {result['message']}" for result in failed)
        typer.echo(messages, err=True)
        raise typer.Exit(1)


@app.command()
def manual(
    config: Annotated[Path | None, typer.Option(exists=True, dir_okay=False)] = None,
) -> None:
    raise typer.Exit(launch_manual(config))
