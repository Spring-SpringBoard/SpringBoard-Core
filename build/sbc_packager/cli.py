import typer

from .application.cli import application_command
from .editor.cli import base_command

app = typer.Typer(add_completion=False, no_args_is_help=True)

app.command("application")(application_command)
app.command("base")(base_command)


def main() -> None:
    app()
