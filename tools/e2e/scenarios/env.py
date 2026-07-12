"""Env tab: focused Lighting, Sky/Fog, and Water scenarios."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import (
    ACTION_Y,
    EDITOR_BUTTON_Y,
    TAB_X,
    TAB_Y,
    dialog_left,
    panel_left,
    window_size,
)

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
    x: int,
    y: int,
    command: str,
    key: str,
    pick_x: int,
) -> None:
    run_state.click(left + x, y, delay=0.25)
    run_state.click(pick_x, 300, delay=0.12)
    run_state.click(1138, 473, delay=0.45)
    run_state.assert_any_command(
        command,
        **{key: lambda value: isinstance(value, list)},
    )


def lighting_panel(run_state: E2ERun) -> None:
    """Lighting only: shadow mode, sun vector, colors, and densities."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.2)
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.4)
    run_state.screenshot("lighting-open")

    run_state.click(left + 180, 222, delay=0.15)
    run_state.key("Down", delay=0.1)
    run_state.key("Return", delay=0.25)
    for x, key, value in (
        (92, "dirX", "0.25"),
        (200, "dirY", "0.35"),
        (300, "dirZ", "0.75"),
    ):
        _edit_number(run_state, left + x, 265, value)
        run_state.assert_any_command(
            "SetSunParametersCommand",
            **{key: lambda actual, expected=float(value): abs(actual - expected) < 0.01},
        )

    for x, y, key, pick_x in (
        (150, 332, "groundDiffuseColor", 900),
        (320, 332, "groundAmbientColor", 880),
        (150, 375, "groundSpecularColor", 920),
        (150, 484, "unitDiffuseColor", 940),
        (320, 484, "unitAmbientColor", 860),
        (150, 527, "unitSpecularColor", 900),
    ):
        _commit_color(run_state, left, x, y, "SetSunLightingCommand", key, pick_x)

    for y, key, value in (
        (418, "groundShadowDensity", "0.65"),
        (570, "modelShadowDensity", "0.55"),
    ):
        _edit_number(run_state, left + 100, y, value)
        run_state.assert_any_command(
            "SetSunLightingCommand",
            **{key: lambda actual, expected=float(value): abs(actual - expected) < 0.01},
        )
    run_state.screenshot("lighting-all-fields")


def sky_panel(run_state: E2ERun) -> None:
    """Sky/Fog only: all atmosphere colors, fog bounds, and skybox picker."""
    run_state.focus()
    left = panel_left(run_state)
    modal_left = dialog_left(run_state)
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.2)
    run_state.click(left + 110, EDITOR_BUTTON_Y, delay=0.4)
    run_state.screenshot("sky-open")

    for x, y, key, pick_x in (
        (150, 192, "sunColor", 900),
        (320, 192, "skyColor", 930),
        (150, 237, "cloudColor", 870),
        (150, 347, "fogColor", 950),
    ):
        _commit_color(run_state, left, x, y, "SetAtmosphereCommand", key, pick_x)
    for x, y, value, key in (
        (260, 347, "0.2", "fogStart"),
        (90, 390, "0.85", "fogEnd"),
    ):
        _edit_number(run_state, left + x, y, value)
        run_state.assert_any_command(
            "SetAtmosphereCommand",
            **{key: lambda actual, expected=float(value): abs(actual - expected) < 0.01},
        )

    run_state.click(left + 64, 280, delay=0.6)
    run_state.screenshot("skybox-picker")
    run_state.click(modal_left + 50, 335, delay=0.35)
    run_state.click(modal_left + 343, 603, delay=0.6)
    run_state.screenshot("sky-all-fields")


def water_panel(run_state: E2ERun) -> None:
    """Water only, after making a broad below-zero basin and enabling water 4."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    modal_left = dialog_left(run_state)
    run_state.click(width - 610, height - 115, delay=0.3)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.2)
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.45)
    run_state.click(left + 42, 365, delay=0.3)
    _edit_number(run_state, left + 92, 612, "3000")
    _edit_number(run_state, left + 92, 692, "1000")
    _edit_number(run_state, left + 92, 741, "-300")
    run_state.click(left + 112, ACTION_Y, delay=0.4)
    for x, y in (
        (width // 4, height // 3),
        (width // 2, height // 3),
        (width // 4, height * 2 // 3),
        (width // 2, height * 2 // 3),
    ):
        run_state.drag(x, y, x + 100, y + 60, steps=5)
    run_state.assert_any_command("TerrainLevelCommand", height=-300.0, strength=1000.0)
    run_state.move(left + 450, 1100, delay=0.3)
    run_state.screenshot("basin-below-zero")
    run_state.key("Escape", delay=0.2)
    run_state.key("Return", delay=0.2)
    run_state.type_text("/water 4")
    run_state.key("Return", delay=0.6)

    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.2)
    run_state.click(left + 182, EDITOR_BUTTON_Y, delay=0.45)
    run_state.screenshot("water-open-visible")
    run_state.click(left + 138, 193, delay=0.25)
    run_state.assert_any_command("SetWaterParamsCommand", forceRendering=True)

    for x, y, value, key in (
        (250, 193, "6", "numTiles"),
        (90, 302, "9", "perlinStartFreq"),
        (250, 302, "4", "perlinLacunarity"),
        (90, 344, "0.7", "perlinAmplitude"),
        (90, 411, "0.8", "diffuseFactor"),
        (90, 477, "1.2", "specularFactor"),
        (250, 477, "24", "specularPower"),
        (90, 563, "0.9", "ambientFactor"),
        (90, 630, "0.25", "fresnelMin"),
        (250, 630, "0.75", "fresnelMax"),
        (90, 673, "5", "fresnelPower"),
        (90, 717, "1.1", "reflectionDistortion"),
        (90, 783, "2.2", "blurBase"),
        (250, 783, "1.7", "blurExponent"),
        (90, 1024, "2", "repeatX"),
        (250, 1024, "3", "repeatY"),
    ):
        _edit_number(run_state, left + x, y, value)
        run_state.assert_any_command(
            "SetWaterParamsCommand",
            **{key: lambda actual, expected=float(value): abs(actual - expected) < 0.01},
        )

    for x, y, key, pick_x in (
        (320, 411, "diffuseColor", 900),
        (150, 520, "specularColor", 930),
        (220, 849, "planeColor", 870),
    ):
        _commit_color(run_state, left, x, y, "SetWaterParamsCommand", key, pick_x)
    run_state.click(left + 84, 849, delay=0.2)
    run_state.assert_any_command("SetWaterParamsCommand", hasWaterPlane=False)
    run_state.click(left + 84, 914, delay=0.2)
    run_state.assert_any_command("SetWaterParamsCommand", shoreWaves=False)

    for x, y, key in (
        (87, 237, "normalTexture"),
        (180, 914, "foamTexture"),
        (60, 980, "texture"),
    ):
        run_state.click(left + x, y, delay=0.55)
        run_state.click(modal_left + 50, 335, delay=0.35)
        run_state.click(modal_left + 343, 603, delay=0.6)
        run_state.assert_any_command(
            "SetWaterParamsCommand",
            **{key: lambda path: isinstance(path, str) and bool(path)},
        )
    run_state.move(left + 450, 1100, delay=0.3)
    run_state.screenshot("water-all-fields-visible")


SCENARIOS = {
    "lighting_panel": lighting_panel,
    "sky_panel": sky_panel,
    "water_panel": water_panel,
}
