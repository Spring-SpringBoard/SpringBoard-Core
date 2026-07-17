"""The panel shell itself: tabs, every editor, dialogs, notifications, and the
native panel's golden walk-through."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import (
    DIALOG,
    EDITORS,
    ENV,
    MISC,
    SHELL,
    TAB_X,
    TAB_Y,
    TOOLBAR,
    dialog_point,
    editor_point,
    panel_left,
    panel_point,
)
from scenarios.registry import scenario

# Modal captures include the map behind them. Its terrain render varies by a
# few thousand pixels between otherwise identical paused runs; panel-only
# captures stay pixel-exact.
FULL_FRAME_TOLERANCE = 15_000

if TYPE_CHECKING:
    from runner import E2ERun


@scenario(uis=("chili", "rmlui", "rust"), target="main-panel", crop="right-panel")
def main_panel_tabs(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    for name, offset_x in TAB_X.items():
        run_state.click(left + offset_x, TAB_Y, delay=0.18)
        run_state.screenshot(f"tab-{name}")


# Every registered editor, so none of them is left untried. Tab -> how many
# editor buttons that tab has.
_TABS = (("objects",), ("map",), ("env",), ("misc",))


@scenario(uis=("rmlui", "rust"), crop="right-panel")
def all_editors(run_state: E2ERun) -> None:
    """Open every editor in every tab. Editors are lazily created, so a broken
    one only shows up when its button is clicked."""
    run_state.focus()
    left = panel_left(run_state)

    for (tab_name,) in _TABS:
        run_state.click(left + TAB_X[tab_name], TAB_Y, delay=0.3)
        for editor_name in EDITORS[tab_name]:
            run_state.click(*editor_point(left, tab_name, editor_name), delay=0.7)
            run_state.screenshot(f"{tab_name}-{editor_name}")


@scenario(uis=("rmlui",))
def dialogs(run_state: E2ERun) -> None:
    """Editors and dialogs that build controls outside the panel: Misc ->
    Diplomacy and the New Project dialog."""
    run_state.focus()
    left = panel_left(run_state)

    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.2)
    run_state.click(*editor_point(left, "misc", "diplomacy"), delay=0.8)
    run_state.screenshot("diplomacy")

    run_state.click(*panel_point(left, TOOLBAR["new_project"]), delay=1.0)
    run_state.screenshot_root("new-project")
    run_state.key("Escape", delay=0.3)


@scenario(uis=("chili", "rmlui"))
def notifications(run_state: E2ERun) -> None:
    """Export with no saved project posts a warning notification (SB.NotifyWarn).
    In RmlUi that must come from RmlUiNotifications, not Chotify (which is Chili)."""
    run_state.focus()
    left = panel_left(run_state)

    run_state.screenshot("before")
    # Toolbar action buttons, 6th is Export.
    run_state.click(*panel_point(left, TOOLBAR["export"]), delay=1.0)
    run_state.screenshot("warning")
    # time=3, so it must be gone a few seconds later (the editor runs paused, so
    # expiry cannot be driven off game seconds).
    run_state.move(left - 200, 400, delay=4.0)
    run_state.screenshot("expired")


@scenario(crop="right-panel")
def native_panel(run_state: E2ERun) -> None:
    """The native (Rust) right-hand panel.

    Every capture is a golden compared pixel-exactly, and the field edit has to
    prove itself by emitting the command the engine would act on. `SB` boots
    paused with a fixed camera, so the frame is deterministic.
    """
    run_state.focus()
    left = panel_left(run_state)

    # Top-right of the saturation/value square is full saturation and value, so
    # the colour there is the pure hue under the cursor: red.
    def is_red(rgba: object) -> bool:
        return (
            isinstance(rgba, list)
            and rgba[0] > 0.9
            and rgba[1] < 0.1
            and rgba[2] < 0.1
        )

    run_state.golden("shell-objects-tab")

    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.5)
    run_state.golden("shell-env-tab")

    run_state.click(*editor_point(left, "env", "lighting"), delay=0.7)
    run_state.golden("lighting-open")

    # Click the Shadow Density display to enter edit mode, replace the value,
    # and commit. This must reach the command bridge as SetSunLightingCommand
    # carrying exactly the value we typed.
    run_state.click(*panel_point(left, SHELL["lighting_shadow_density"]), delay=0.4)
    run_state.golden("lighting-density-editing")

    run_state.key("ctrl+a", delay=0.15)
    run_state.type_text("0.25")
    run_state.key("Return", delay=0.6)

    run_state.assert_command("SetSunLightingCommand", groundShadowDensity=0.25)
    run_state.golden("lighting-density-committed")

    # Clicking a colour field opens the picker modal, not an inline editor. The
    # modal sits clear of the panel, so its captures span the frame -- but not
    # the console strip, whose boot log prints pointer addresses that change
    # every run.
    run_state.click(*panel_point(left, SHELL["lighting_ground_diffuse"]), delay=0.6)
    run_state.golden("picker-open", crop="no-console", tolerance=FULL_FRAME_TOLERANCE)

    # Drag to the top-right of the saturation/value square: full saturation,
    # full value, so the colour becomes the pure hue under the cursor.
    run_state.drag(
        *dialog_point(run_state, DIALOG["color_gradient_start"]),
        *dialog_point(run_state, DIALOG["color_gradient_end"]),
        steps=6,
    )
    run_state.golden("picker-dragged", crop="no-console", tolerance=FULL_FRAME_TOLERANCE)

    # Dragging previews live: the engine has already taken the colour before OK
    # is pressed. Previews never reach the undo history.
    run_state.assert_previews("SetSunLightingCommand", groundDiffuseColor=is_red)

    run_state.click(*dialog_point(run_state, DIALOG["color_ok_native"]), delay=0.6)
    run_state.golden("picker-accepted")

    # Accepting commits exactly one undoable command with the same colour.
    run_state.assert_command("SetSunLightingCommand", groundDiffuseColor=is_red)

    # Env -> Water: checkbox + numerics, all through SetWaterParamsCommand.
    run_state.click(*editor_point(left, "env", "water"), delay=0.7)
    run_state.golden("water-open")

    run_state.click(*panel_point(left, ENV["water_forced_rendering"]), delay=0.5)
    run_state.golden("water-checkbox")
    run_state.assert_command("SetWaterParamsCommand", forceRendering=True)

    # Misc -> Info: text fields, backed by the project model rather than the engine.
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.4)
    run_state.golden("shell-misc-tab")
    run_state.click(*editor_point(left, "misc", "info"), delay=0.7)
    run_state.golden("info-open")

    run_state.click(*panel_point(left, MISC["info_name"]), delay=0.3)
    run_state.key("ctrl+a", delay=0.15)
    run_state.type_text("Ported")
    run_state.key("Return", delay=0.6)
    run_state.golden("info-name-typed")

    run_state.assert_command("SetScenarioInfoCommand")

    # Env -> Sky: the Skybox asset field opens the VFS asset picker.
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.4)
    run_state.click(*editor_point(left, "env", "sky"), delay=0.7)
    run_state.golden("sky-open")
    run_state.click(*panel_point(left, ENV["sky_skybox"]), delay=0.8)
    run_state.golden("asset-picker-open", crop="no-console", tolerance=FULL_FRAME_TOLERANCE)
    run_state.click(*dialog_point(run_state, DIALOG["skybox_cancel"]), delay=0.6)

    # Env -> Water: the normal-texture field browses bitmaps/ and picking a file
    # must emit SetWaterParamsCommand carrying its VFS path.
    run_state.click(*editor_point(left, "env", "water"), delay=0.7)
    # Normal texture now sits directly below NumTiles, before the perlin group.
    run_state.click(*panel_point(left, SHELL["water_normal_texture"]), delay=0.8)
    run_state.golden(
        "asset-picker-bitmaps", crop="no-console", tolerance=FULL_FRAME_TOLERANCE
    )

    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=0.5)
    run_state.golden(
        "asset-picker-selected", crop="no-console", tolerance=FULL_FRAME_TOLERANCE
    )
    run_state.click(*dialog_point(run_state, DIALOG["asset_ok"]), delay=0.8)

    def is_bitmap(path: object) -> bool:
        return (
            isinstance(path, str)
            and path.startswith("bitmaps/")
            and "bitmaps/bitmaps" not in path
        )

    run_state.assert_command("SetWaterParamsCommand", normalTexture=is_bitmap)
    run_state.golden("asset-picked")
