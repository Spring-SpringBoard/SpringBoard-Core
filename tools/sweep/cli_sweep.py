"""Capture the asset shader in the running editor.

Purpose: look at every channel of a generated asset at sizes where defects are
actually visible. A single mid-distance frame hides both ends -- tiling seams and
grain only resolve up close, while blotchy low-frequency noise only reads far away.

Three commands, cheapest first, all the same sweep with different arguments:

    just sweep-one        # one picture, one angle -- does it render at all
    just sweep-angle      # every debug view, one angle
    just sweep-all        # every debug view, every angle

Angles live one per module in `angles/`; `sweep-angle` and `sweep-all` take their
names. Panel changes and captures go over the control channel, so there are no
screen coordinates and no sleeps anywhere in here.
"""

from pathlib import Path
from typing import Annotated

import typer

from .registry import NAMES, angles
from .run import sweep, sweep_field

app = typer.Typer(add_completion=False, help=__doc__)

ARTIFACTS = Path("artifacts/sweep")

_Project = Annotated[str, typer.Option(help="Project holding the asset")]
_Scene = Annotated[str, typer.Option(help="featureDef to place")]
_Out = Annotated[Path, typer.Option(help="Where to write captures")]
_Angle = Annotated[str, typer.Option(help=f"Angle to use. One of: {', '.join(NAMES)}")]


@app.command()
def one(
    angle: _Angle = "close",
    project: _Project = "6",
    scene: _Scene = "gen_arch",
    out: _Out = ARTIFACTS,
) -> None:
    """One picture from one angle: the quickest check that anything renders."""
    sweep(angles((angle,)), out, project, scene, view_limit=1)


@app.command()
def one_angle(
    angle: _Angle = "close",
    project: _Project = "6",
    scene: _Scene = "gen_arch",
    out: _Out = ARTIFACTS,
) -> None:
    """Every debug view from a single angle."""
    sweep(angles((angle,)), out, project, scene)


@app.command()
def field(
    name: Annotated[str, typer.Option(help="Schema name of the field, e.g. detailStrength")],
    values: Annotated[str, typer.Option(help="Comma-separated settings to capture")],
    angle: _Angle = "mid",
    project: _Project = "6",
    scene: _Scene = "gen_arch",
    out: _Out = ARTIFACTS,
) -> None:
    """Sweep one numeric shader field, capturing the final view at each value.

    For calibrating a uniform against a measurement instead of by eye. One engine session
    covers every value, because the field goes over the control channel and needs no reload.
    """
    settings = tuple(float(value) for value in values.split(","))
    sweep_field(name, settings, angles((angle,)), out, project, scene)


@app.command()
def all_angles(
    project: _Project = "6",
    scene: _Scene = "gen_arch",
    out: _Out = ARTIFACTS,
) -> None:
    """Every debug view from every angle. One engine session per angle."""
    sweep(angles(), out, project, scene)


if __name__ == "__main__":
    app()
