from pathlib import Path
from typing import Annotated

import typer

from .engine import boot, launch_manual

app = typer.Typer(no_args_is_help=True)


@app.command()
def boot_editor() -> None:
    typer.echo(boot(tags=["__startup_only__"]))


@app.command()
def manual(
    config: Annotated[Path | None, typer.Option(exists=True, dir_okay=False)] = None,
) -> None:
    raise typer.Exit(launch_manual(config))
