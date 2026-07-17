"""Env tab: focused Lighting, Sky/Fog, and Water scenarios."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import (
    DIALOG,
    COLOR_PICKER,
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
    STATUS,
    TAB_X,
    TAB_Y,
    dialog_point,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)
from scenarios.registry import scenario

if TYPE_CHECKING:
    from runner import E2ERun


def _edit_number(run_state: E2ERun, x: int, y: int, value: str) -> None:
    run_state.click(x, y, delay=0.1)
    run_state.key("ctrl+a", delay=0.06)
    run_state.type_text(value)
    run_state.key("Return", delay=0.22)


def _commit_color(
    run_state: E2ERun,
    left: int,
    point: tuple[int, int],
    command: str,
    key: str,
    pick_x: int,
) -> None:
    run_state.click(*panel_point(left, point), delay=0.25)
    run_state.click(pick_x, COLOR_PICKER["sample_y"], delay=0.12)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok_compact"]), delay=0.45)
    run_state.assert_any_command(
        command,
        **{key: lambda value: isinstance(value, list)},
    )


@scenario(uis=("chili", "rmlui", "rust"), crop="right-panel")
def lighting_panel(run_state: E2ERun) -> None:
    """Lighting only: shadow mode, sun vector, colors, and densities."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.2)
    run_state.click(*editor_point(left, "env", "lighting"), delay=0.4)
    run_state.screenshot("lighting-open")

    run_state.click(*panel_point(left, ENV["lighting_shadow_mode"]), delay=0.15)
    run_state.key("Down", delay=0.1)
    run_state.key("Return", delay=0.25)
    for key, point, value in ENV_LIGHTING_NUMBERS[:3]:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetSunParametersCommand",
            **{key: lambda actual, expected=float(value): abs(actual - expected) < 0.01},
        )

    for key, point, pick_x in ENV_LIGHTING_COLORS:
        _commit_color(run_state, left, point, "SetSunLightingCommand", key, pick_x)

    for key, point, value in ENV_LIGHTING_NUMBERS[3:]:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetSunLightingCommand",
            **{key: lambda actual, expected=float(value): abs(actual - expected) < 0.01},
        )
    run_state.screenshot("lighting-all-fields")


@scenario(crop="right-panel")
def sky_panel(run_state: E2ERun) -> None:
    """Sky/Fog only: all atmosphere colors, fog bounds, and skybox picker."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.2)
    run_state.click(*editor_point(left, "env", "sky"), delay=0.4)
    run_state.screenshot("sky-open")

    for key, point, pick_x in ENV_SKY_COLORS:
        _commit_color(run_state, left, point, "SetAtmosphereCommand", key, pick_x)
    for key, point, value in ENV_SKY_NUMBERS:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetAtmosphereCommand",
            **{key: lambda actual, expected=float(value): abs(actual - expected) < 0.01},
        )

    run_state.click(*panel_point(left, ENV["sky_skybox"]), delay=0.6)
    run_state.screenshot("skybox-picker")
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=0.35)
    run_state.click(*dialog_point(run_state, DIALOG["asset_ok"]), delay=0.6)
    run_state.screenshot("sky-all-fields")


@scenario()
def water_panel(run_state: E2ERun) -> None:
    """Water only, after making a broad below-zero basin and enabling water 4."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    run_state.click(width - STATUS["map_toggle_from_right"][0], height - STATUS["map_toggle_from_right"][1], delay=0.3)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.2)
    run_state.click(*editor_point(left, "map", "terrain"), delay=0.45)
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=0.3)
    _edit_number(run_state, *panel_point(left, ENV["terrain_size"]), "3000")
    _edit_number(run_state, *panel_point(left, ENV["terrain_strength"]), "1000")
    _edit_number(run_state, *panel_point(left, ENV["terrain_height"]), "-300")
    run_state.click(*panel_point(left, ENV["terrain_set"]), delay=0.4)
    for x, y in (
        (width // 4, height // 3),
        (width // 2, height // 3),
        (width // 4, height * 2 // 3),
        (width // 2, height * 2 // 3),
    ):
        run_state.drag(x, y, x + 100, y + 60, steps=5)
    run_state.assert_any_command("TerrainLevelCommand", height=-300.0, strength=1000.0)
    run_state.move(*panel_point(left, PARK_PANEL_LOW), delay=0.3)
    run_state.screenshot("basin-below-zero")
    run_state.key("Escape", delay=0.2)
    run_state.key("Return", delay=0.2)
    run_state.type_text("/water 4")
    run_state.key("Return", delay=0.6)

    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.2)
    run_state.click(*editor_point(left, "env", "water"), delay=0.45)
    run_state.screenshot("water-open-visible")
    run_state.click(*panel_point(left, ENV["water_forced_rendering"]), delay=0.25)
    run_state.assert_any_command("SetWaterParamsCommand", forceRendering=True)

    for key, point, value in ENV_WATER_NUMBERS:
        _edit_number(run_state, *panel_point(left, point), value)
        run_state.assert_any_command(
            "SetWaterParamsCommand",
            **{key: lambda actual, expected=float(value): abs(actual - expected) < 0.01},
        )

    for key, point, pick_x in ENV_WATER_COLORS:
        _commit_color(run_state, left, point, "SetWaterParamsCommand", key, pick_x)
    run_state.click(*panel_point(left, ENV["water_plane"]), delay=0.2)
    run_state.assert_any_command("SetWaterParamsCommand", hasWaterPlane=False)
    run_state.click(*panel_point(left, ENV["water_shore_waves"]), delay=0.2)
    run_state.assert_any_command("SetWaterParamsCommand", shoreWaves=False)

    for key, point in ENV_WATER_ASSETS:
        run_state.click(*panel_point(left, point), delay=0.55)
        run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=0.35)
        run_state.click(*dialog_point(run_state, DIALOG["asset_ok"]), delay=0.6)
        run_state.assert_any_command(
            "SetWaterParamsCommand",
            **{key: lambda path: isinstance(path, str) and bool(path)},
        )
    run_state.move(*panel_point(left, PARK_PANEL_LOW), delay=0.3)
    run_state.screenshot("water-all-fields-visible")
