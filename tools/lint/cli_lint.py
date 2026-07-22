import typer

from . import mod_only_declares, no_dead_commands, py_step_down, rust_step_down

app = typer.Typer(no_args_is_help=True)


@app.command("rust-step-down")
def rust_step_down_command() -> None:
    raise typer.Exit(rust_step_down.check())


@app.command("py-step-down")
def python_step_down_command() -> None:
    raise typer.Exit(py_step_down.check())


@app.command("no-dead-commands")
def dead_commands_command(show_all: bool = typer.Option(False, "--all"), fail: bool = False) -> None:
    raise typer.Exit(no_dead_commands.check(show_all=show_all, fail=fail))


@app.command("mod-only-declares")
def module_declarations_command() -> None:
    raise typer.Exit(mod_only_declares.check())
