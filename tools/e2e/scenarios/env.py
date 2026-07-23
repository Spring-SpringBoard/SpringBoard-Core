"""Env tab: focused Lighting, Sky/Fog, and Water scenarios."""

from typing import TYPE_CHECKING

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
    run_state.click(left + TAB_X["env"], TAB_Y, delay=Delay.MS_200)
    run_state.click(*editor_point(left, "env", "lighting"), delay=Delay.MS_400)
    run_state.screenshot("lighting-open")

    run_state.click(*panel_point(left, ENV["lighting_shadow_mode"]), delay=Delay.MS_300)
    run_state.click(*panel_point(left, dropdown_option(ENV["lighting_shadow_mode"], 2)), delay=Delay.MS_350)
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


@scenario(crop="right-panel")
def sky_panel(run_state: "RunState") -> None:
    """Sky/Fog only: all atmosphere colors, fog bounds, and skybox picker."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["env"], TAB_Y, delay=Delay.MS_200)
    run_state.click(*editor_point(left, "env", "sky"), delay=Delay.MS_400)
    run_state.screenshot("sky-open")

    for key, point, pick_x in ENV_SKY_COLORS:
        _commit_color(run_state, left, point, "SetAtmosphereCommand", key, pick_x)
    for key, point, value in ENV_SKY_NUMBERS:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetAtmosphereCommand",
            **{key: number_close(float(value))},
        )

    run_state.click(*panel_point(left, ENV["sky_skybox"]), delay=Delay.MS_600)
    run_state.screenshot_root("skybox-picker")
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=Delay.MS_350)
    run_state.click(*dialog_point(run_state, DIALOG["asset_ok"]), delay=Delay.MS_600)
    run_state.screenshot("sky-all-fields")


@scenario()
def water_panel(run_state: "RunState") -> None:
    """Water only, after making a broad below-zero basin and enabling water 4."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.MS_200)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.MS_450)
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.MS_300)
    _edit_number(run_state, *panel_point(left, ENV["terrain_size"]), "3000")
    _edit_number(run_state, *panel_point(left, ENV["terrain_strength"]), "1000")
    _edit_number(run_state, *panel_point(left, ENV["terrain_height"]), "-300")
    run_state.click(*panel_point(left, ENV["terrain_set"]), delay=Delay.MS_400)
    for x, y in (
        (width // 4, height // 3),
        (width // 2, height // 3),
        (width // 4, height * 2 // 3),
        (width // 2, height * 2 // 3),
    ):
        run_state.drag(x, y, x + 100, y + 60, steps=5)
    run_state.assert_any_command("TerrainLevelCommand", height=-300.0, strength=1000.0)
    run_state.move(*panel_point(left, PARK_PANEL_LOW), delay=Delay.MS_300)
    run_state.screenshot("basin-below-zero")
    run_state.key("Escape", delay=Delay.MS_200)
    run_state.key("Return", delay=Delay.MS_200)
    run_state.type_text("/water 4")
    run_state.key("Return", delay=Delay.MS_600)

    run_state.click(left + TAB_X["env"], TAB_Y, delay=Delay.MS_200)
    run_state.click(*editor_point(left, "env", "water"), delay=Delay.MS_450)
    run_state.screenshot("water-open-visible")
    run_state.click(*panel_point(left, ENV["water_forced_rendering"]), delay=Delay.MS_250)
    run_state.assert_any_command("SetWaterParamsCommand", forceRendering=True)

    for key, point, value in ENV_WATER_NUMBERS:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetWaterParamsCommand",
            **{key: number_close(float(value))},
        )
    for key, point, pick_x in ENV_WATER_COLORS:
        _commit_color(run_state, left, point, "SetWaterParamsCommand", key, pick_x)
    run_state.click(*panel_point(left, ENV["water_plane"]), delay=Delay.MS_200)
    run_state.assert_any_command("SetWaterParamsCommand", hasWaterPlane=False)
    run_state.click(*panel_point(left, ENV["water_shore_waves"]), delay=Delay.MS_200)
    run_state.assert_any_command("SetWaterParamsCommand", shoreWaves=False)

    for key, point in ENV_WATER_ASSETS:
        run_state.click(*panel_point(left, point), delay=Delay.MS_550)
        run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=Delay.MS_350)
        run_state.click(*dialog_point(run_state, DIALOG["asset_ok"]), delay=Delay.MS_600)
        run_state.assert_any_command(
            "SetWaterParamsCommand",
            **{key: nonempty_string},
        )
    run_state.move(*panel_point(left, PARK_PANEL_LOW), delay=Delay.MS_300)
    run_state.screenshot("water-all-fields-visible")


def _edit_number(run_state: "RunState", x: int, y: int, value: str) -> None:
    run_state.fill_text(x, y, value, click_delay=Delay.MS_100, commit_delay=Delay.MS_220)


def _commit_color(
    run_state: "RunState",
    left: int,
    point: tuple[int, int],
    command: str,
    key: str,
    pick_x: int,
) -> None:
    run_state.click(*panel_point(left, point), delay=Delay.MS_250)
    run_state.click(pick_x, COLOR_PICKER["sample_y"], delay=Delay.MS_120)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok_compact"]), delay=Delay.MS_450)
    run_state.assert_any_command(command, **{key: is_list})
