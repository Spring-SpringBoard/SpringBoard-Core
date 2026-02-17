from __future__ import annotations

import typer

from .cli_download_engine import download_engine_command
from .cli_make_package_json import make_package_json_command
from .cli_package import package_command
from .cli_prepare import prepare_command

app = typer.Typer(add_completion=False, no_args_is_help=True)

app.command("prepare")(prepare_command)
app.command("download-engine")(download_engine_command)
app.command("make-package-json")(make_package_json_command)
app.command("package")(package_command)


def main() -> None:
    app()
