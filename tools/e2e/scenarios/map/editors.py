"""Typed map editor state scenarios."""

from typing import TYPE_CHECKING

import pytest

from e2e.driver.utils.models import list_item_matches, number_close
from e2e.scenarios.helpers.registry import scenario

from .common import TERRAIN_PATTERN_PATH

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario()
def map_editors(run_state: "RunState") -> None:
    """Map editor state, through the editor seam rather than panel widgets.

    Brush strokes, material picking and shading dialogs are interaction
    contracts and have dedicated X11 coverage.  This scenario owns the state
    that those interactions consume.
    """
    terrain = run_state.control.editor("heightmapEditor")
    for field, value in {
        "size": 140.0,
        "rotation": 15.0,
        "strength": 8.5,
        "height": 25.0,
        "applyDir": "Only Raise",
    }.items():
        setattr(terrain, field, value)
        actual = terrain.get(field)
        assert actual == value, f"{terrain.name}.{field}: expected {value!r}, got {actual!r}"

    texture = run_state.control.editor("textureEditor")
    for field, value in {
        "material": "tiles",
        "patternTexture": TERRAIN_PATTERN_PATH,
        "size": 180.0,
        "rotation": 20.0,
        "texScale": 3.5,
        "texRotation": 30.0,
        "texOffsetX": 0.25,
        "texOffsetY": -0.5,
        "mode": "Overlay",
        "kernelMode": "sharpen",
        "strength": 0.75,
        "falloffFactor": 0.4,
        "featureFactor": 0.6,
        "value": 0.8,
        "voidFactor": 0.5,
        "splatTexScale": 1.25,
        "splatTexMult": 0.75,
        "dntsIndex": 1.0,
        "exclusive": True,
        "diffuseColor": (0.2, 0.4, 0.8, 1.0),
        "diffuseEnabled": False,
        "specularEnabled": False,
        "emissionEnabled": True,
        "reflEnabled": True,
    }.items():
        texture.set(field, value)
        actual = texture.get(field)
        if isinstance(value, float):
            assert float(actual) == pytest.approx(value), f"{texture.name}.{field}: expected {value!r}, got {actual!r}"
        elif isinstance(value, tuple):
            assert actual == pytest.approx(value), f"{texture.name}.{field}: expected {value!r}, got {actual!r}"
        else:
            assert actual == value, f"{texture.name}.{field}: expected {value!r}, got {actual!r}"

    metal = run_state.control.editor("metalEditor")
    for field, value in {"size": 180.0, "rotation": 25.0, "amount": 3.25}.items():
        setattr(metal, field, value)
        actual = metal.get(field)
        assert float(actual) == pytest.approx(value), f"{metal.name}.{field}: expected {value!r}, got {actual!r}"

    grass = run_state.control.editor("grassEditor")
    for field, value in {"grassDetail": 7.0, "size": 160.0, "rotation": -20.0}.items():
        setattr(grass, field, value)
        actual = grass.get(field)
        assert float(actual) == pytest.approx(value), f"{grass.name}.{field}: expected {value!r}, got {actual!r}"

    settings = run_state.control.editor("terrainSettingsEditor")
    for field, value in {
        "voidWater": True,
        "voidGround": True,
        "splatDetailNormalDiffuseAlpha": True,
    }.items():
        setattr(settings, field, value)
        run_state.assert_any_command("SetMapRenderingParamsCommand", **{field: value})
    for field, value, index in (
        ("splatTexScale0", 2.5, 0),
        ("splatTexScale1", 3.0, 1),
        ("splatTexMult0", 0.25, 0),
        ("splatTexMult1", 0.5, 1),
    ):
        setattr(settings, field, value)
        command_field = "splatTexScales" if "Scale" in field else "splatTexMults"
        run_state.assert_any_command(
            "SetMapRenderingParamsCommand",
            **{command_field: list_item_matches(index, number_close(value))},
        )
