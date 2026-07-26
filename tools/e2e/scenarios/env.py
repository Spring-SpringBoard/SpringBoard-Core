"""Env tab: focused Lighting, Sky/Fog, and Water scenarios."""

from typing import TYPE_CHECKING

import pytest
from control import UnknownNameError

from e2e.driver.timing import Delay
from e2e.driver.utils.models import is_list, nonempty_string, number_close

from .helpers.geometry import (
    COLOR_PICKER,
    DIALOG,
    ENV,
    ENV_LIGHTING_COLORS,
    ENV_LIGHTING_NUMBERS,
    ENV_SKY_COLORS,
    ENV_SKY_NUMBERS,
    ENV_WATER_ASSETS,
    ENV_WATER_COLORS,
    ENV_WATER_NUMBERS,
    MAP,
    PARK_PANEL_LOW,
    TAB_X,
    TAB_Y,
    dialog_point,
    dropdown_option,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)
from .helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario(crop="right-panel")
def lighting_panel(run_state: "RunState") -> None:
    """Lighting only: shadow mode, sun vector, colors, and densities."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["env"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "env", "lighting"), delay=Delay.SETTLE)
    run_state.screenshot("lighting-open")

    run_state.click(*panel_point(left, ENV["lighting_shadow_mode"]), delay=Delay.FRAME)
    run_state.click(*panel_point(left, dropdown_option(ENV["lighting_shadow_mode"], 2)), delay=Delay.SETTLE)
    for key, point, value in ENV_LIGHTING_NUMBERS[:3]:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetSunParametersCommand",
            **{key: number_close(float(value))},
        )

    for key, point, pick_x in ENV_LIGHTING_COLORS:
        _commit_color(run_state, left, point, "SetSunLightingCommand", key, pick_x)

    for key, point, value in ENV_LIGHTING_NUMBERS[3:]:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetSunLightingCommand",
            **{key: number_close(float(value))},
        )
    run_state.screenshot("lighting-all-fields")


# `lighting_panel` above proves the panel's controls work. This proves lighting
# does: same editor, same commit path, driven through the control channel with
# no pointer, no coordinates and no waits.
SUN_DIRECTION = {"sunDirX": ("dirX", 0.42), "sunDirY": ("dirY", 0.66), "sunDirZ": ("dirZ", 0.28)}
DENSITIES = {"groundShadowDensity": 0.75, "modelShadowDensity": 0.4}
LIGHTING_COLORS = {
    "groundDiffuseColor": (0.9, 0.45, 0.2, 1.0),
    "groundAmbientColor": (0.2, 0.25, 0.5, 1.0),
    "groundSpecularColor": (0.6, 0.6, 0.7, 1.0),
    "unitDiffuseColor": (0.8, 0.7, 0.3, 1.0),
    "unitAmbientColor": (0.3, 0.3, 0.4, 1.0),
    "unitSpecularColor": (0.5, 0.55, 0.6, 1.0),
}


@scenario()
def lighting(run_state: "RunState") -> None:
    """Lighting through the control channel: shadow mode, sun vector, colours
    and densities, checked in the commands, in the editor and on the map."""
    sb = run_state.control

    lighting_editor = sb.editor("lightingEditor")
    sun_parameters = sb.commands["SetSunParametersCommand"]
    sun_lighting = sb.commands["SetSunLightingCommand"]

    before = run_state.control_capture("lighting-before")

    # A dropdown: the value is a plain string, so an unlisted one has to be
    # refused rather than quietly stored.
    lighting_editor.shadowMode = "Full"
    with pytest.raises(UnknownNameError):
        lighting_editor.shadowMode = "Fully"
    # Again past the client's own check, so the editor is the one refusing.
    with pytest.raises(UnknownNameError):
        sb.call("ui.set", field="shadowMode", value="Fully")

    for field, (sent_as, value) in SUN_DIRECTION.items():
        setattr(lighting_editor, field, value)
        run_state.assert_any_command("SetSunParametersCommand", **{sent_as: number_close(value)})

    for field, value in DENSITIES.items():
        setattr(lighting_editor, field, value)
        run_state.assert_any_command("SetSunLightingCommand", **{field: number_close(value)})

    for field, color in LIGHTING_COLORS.items():
        lighting_editor.set(field, color)
        run_state.assert_any_command("SetSunLightingCommand", **{field: is_list})

    after = run_state.control_capture("lighting-after")
    run_state.assert_screenshot_pixels(before, after, min_changed=10_000)

    # The editor holds what was set: a command that reached the bridge but was
    # rejected downstream would leave the field where it was.
    assert lighting_editor.groundShadowDensity == 0.75, lighting_editor.groundShadowDensity
    assert lighting_editor.shadowMode == "Full", lighting_editor.shadowMode

    # Commands the channel raises directly, with no field behind them.
    sun_parameters(dirX=0.1, dirY=0.9, dirZ=0.1)
    run_state.assert_any_command("SetSunParametersCommand", dirY=number_close(0.9))
    sun_lighting(groundShadowDensity=0.2)
    run_state.assert_any_command("SetSunLightingCommand", groundShadowDensity=number_close(0.2))


@scenario(crop="right-panel")
def sky_panel(run_state: "RunState") -> None:
    """Sky/Fog only: all atmosphere colors, fog bounds, and skybox picker."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["env"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "env", "sky"), delay=Delay.SETTLE)
    run_state.screenshot("sky-open")

    for key, point, pick_x in ENV_SKY_COLORS:
        _commit_color(run_state, left, point, "SetAtmosphereCommand", key, pick_x)
    for key, point, value in ENV_SKY_NUMBERS:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetAtmosphereCommand",
            **{key: number_close(float(value))},
        )

    run_state.click(*panel_point(left, ENV["sky_skybox"]), delay=Delay.DIALOG)
    run_state.screenshot_root("skybox-picker")
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=Delay.SETTLE)
    run_state.click(*dialog_point(run_state, DIALOG["asset_ok"]), delay=Delay.DIALOG)
    run_state.screenshot("sky-all-fields")


@scenario()
def water_panel(run_state: "RunState") -> None:
    """Water only, after making a broad below-zero basin and enabling water 4."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.DIALOG)
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.FRAME)
    _edit_number(run_state, *panel_point(left, ENV["terrain_size"]), "3000")
    _edit_number(run_state, *panel_point(left, ENV["terrain_strength"]), "1000")
    _edit_number(run_state, *panel_point(left, ENV["terrain_height"]), "-300")
    run_state.click(*panel_point(left, ENV["terrain_set"]), delay=Delay.SETTLE)
    for x, y in (
        (width // 4, height // 3),
        (width // 2, height // 3),
        (width // 4, height * 2 // 3),
        (width // 2, height * 2 // 3),
    ):
        run_state.drag(x, y, x + 100, y + 60, steps=5)
    run_state.assert_any_command("TerrainLevelCommand", height=-300.0, strength=1000.0)
    run_state.move(*panel_point(left, PARK_PANEL_LOW), delay=Delay.FRAME)
    run_state.screenshot("basin-below-zero")
    run_state.key("Escape", delay=Delay.CONTROL)
    run_state.key("Return", delay=Delay.CONTROL)
    run_state.type_text("/water 4")
    run_state.key("Return", delay=Delay.DIALOG)

    run_state.click(left + TAB_X["env"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "env", "water"), delay=Delay.DIALOG)
    run_state.screenshot("water-open-visible")
    run_state.click(*panel_point(left, ENV["water_forced_rendering"]), delay=Delay.FRAME)
    run_state.assert_any_command("SetWaterParamsCommand", forceRendering=True)

    for key, point, value in ENV_WATER_NUMBERS:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetWaterParamsCommand",
            **{key: number_close(float(value))},
        )
    for key, point, pick_x in ENV_WATER_COLORS:
        _commit_color(run_state, left, point, "SetWaterParamsCommand", key, pick_x)
    run_state.click(*panel_point(left, ENV["water_plane"]), delay=Delay.CONTROL)
    run_state.assert_any_command("SetWaterParamsCommand", hasWaterPlane=False)
    run_state.click(*panel_point(left, ENV["water_shore_waves"]), delay=Delay.CONTROL)
    run_state.assert_any_command("SetWaterParamsCommand", shoreWaves=False)

    for key, point in ENV_WATER_ASSETS:
        run_state.click(*panel_point(left, point), delay=Delay.DIALOG)
        run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=Delay.SETTLE)
        run_state.click(*dialog_point(run_state, DIALOG["asset_ok"]), delay=Delay.DIALOG)
        run_state.assert_any_command(
            "SetWaterParamsCommand",
            **{key: nonempty_string},
        )
    run_state.move(*panel_point(left, PARK_PANEL_LOW), delay=Delay.FRAME)
    run_state.screenshot("water-all-fields-visible")


def _edit_number(run_state: "RunState", x: int, y: int, value: str) -> None:
    run_state.fill_text(x, y, value, click_delay=Delay.INPUT, commit_delay=Delay.FRAME)


def _commit_color(
    run_state: "RunState",
    left: int,
    point: tuple[int, int],
    command: str,
    key: str,
    pick_x: int,
) -> None:
    run_state.click(*panel_point(left, point), delay=Delay.FRAME)
    run_state.click(pick_x, COLOR_PICKER["sample_y"], delay=Delay.CONTROL)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok_compact"]), delay=Delay.DIALOG)
    run_state.assert_any_command(command, **{key: is_list})
