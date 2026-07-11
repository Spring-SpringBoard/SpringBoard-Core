"""The panel shell itself: tabs, every editor, dialogs, notifications, and the
native panel's golden walk-through."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import (
    EDITOR_BUTTON_Y,
    TAB_X,
    TAB_Y,
    dialog_left,
    editor_button_x,
    panel_left,
)

if TYPE_CHECKING:
    from runner import E2ERun


def main_panel_tabs(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    for name, offset_x in TAB_X.items():
        run_state.click(left + offset_x, TAB_Y, delay=0.18)
        run_state.screenshot(f"tab-{name}")


# Every registered editor, so none of them is left untried. Tab -> how many
# editor buttons that tab has.
_TABS = (("objects", 4), ("map", 5), ("env", 3), ("misc", 2))


def all_editors(run_state: E2ERun) -> None:
    """Open every editor in every tab. Editors are lazily created, so a broken
    one only shows up when its button is clicked."""
    run_state.focus()
    left = panel_left(run_state)

    for tab_name, editor_count in _TABS:
        run_state.click(left + TAB_X[tab_name], TAB_Y, delay=0.3)
        for i in range(editor_count):
            run_state.click(left + editor_button_x(i), EDITOR_BUTTON_Y, delay=0.7)
            run_state.screenshot(f"{tab_name}-{i}")


def dialogs(run_state: E2ERun) -> None:
    """Editors and dialogs that build controls outside the panel: Misc ->
    Diplomacy and the New Project dialog."""
    run_state.focus()
    left = panel_left(run_state)

    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.2)
    run_state.click(left + 110, EDITOR_BUTTON_Y, delay=0.8)   # Diplomacy (order 2)
    run_state.screenshot("diplomacy")

    run_state.click(left + 24, 150, delay=1.0)   # toolbar: New Project
    run_state.screenshot_root("new-project")
    run_state.key("Escape", delay=0.3)


def notifications(run_state: E2ERun) -> None:
    """Export with no saved project posts a warning notification (SB.NotifyWarn).
    In RmlUi that must come from RmlUiNotifications, not Chotify (which is Chili)."""
    run_state.focus()
    left = panel_left(run_state)

    run_state.screenshot("before")
    # Toolbar action buttons, 6th is Export.
    run_state.click(left + 239, 150, delay=1.0)
    run_state.screenshot("warning")
    # time=3, so it must be gone a few seconds later (the editor runs paused, so
    # expiry cannot be driven off game seconds).
    run_state.move(left - 200, 400, delay=4.0)
    run_state.screenshot("expired")


def native_panel(run_state: E2ERun) -> None:
    """The native (Rust) right-hand panel.

    Every capture is a golden compared pixel-exactly, and the field edit has to
    prove itself by emitting the command the engine would act on. `SB` boots
    paused with a fixed camera, so the frame is deterministic.
    """
    run_state.focus()
    left = panel_left(run_state)
    modal_left = dialog_left(run_state)

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

    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.7)    # Env -> Lighting
    run_state.golden("lighting-open")

    # Click the Shadow Density display to enter edit mode, replace the value,
    # and commit. This must reach the command bridge as SetSunLightingCommand
    # carrying exactly the value we typed.
    run_state.click(left + 90, 419, delay=0.4)
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
    run_state.click(left + 90, 331, delay=0.6)
    run_state.golden("picker-open", crop="no-console")

    # Drag to the top-right of the saturation/value square: full saturation,
    # full value, so the colour becomes the pure hue under the cursor.
    sv_left, sv_top = modal_left + 10, 252
    run_state.drag(sv_left + 10, sv_top + 170, sv_left + 175, sv_top + 5, steps=6)
    run_state.golden("picker-dragged", crop="no-console")

    # Dragging previews live: the engine has already taken the colour before OK
    # is pressed. Previews never reach the undo history.
    run_state.assert_previews("SetSunLightingCommand", groundDiffuseColor=is_red)

    run_state.click(modal_left + 344, 472, delay=0.6)   # OK
    run_state.golden("picker-accepted")

    # Accepting commits exactly one undoable command with the same colour.
    run_state.assert_command("SetSunLightingCommand", groundDiffuseColor=is_red)

    # Env -> Water: checkbox + numerics, all through SetWaterParamsCommand.
    run_state.click(left + 182, EDITOR_BUTTON_Y, delay=0.7)
    run_state.golden("water-open")

    run_state.click(left + 138, 192, delay=0.5)   # "Forced rendering" checkbox
    run_state.golden("water-checkbox")
    run_state.assert_command("SetWaterParamsCommand", forceRendering=True)

    # Misc -> Info: text fields, backed by the project model rather than the engine.
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.4)
    run_state.golden("shell-misc-tab")
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.7)     # Info
    run_state.golden("info-open")

    run_state.click(left + 200, 190, delay=0.3)   # Name field
    run_state.key("ctrl+a", delay=0.15)
    run_state.type_text("Ported")
    run_state.key("Return", delay=0.6)
    run_state.golden("info-name-typed")

    run_state.assert_command("SetScenarioInfoCommand")

    # Env -> Sky: the Skybox asset field opens the VFS asset picker.
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.4)
    run_state.click(left + 110, EDITOR_BUTTON_Y, delay=0.7)   # Sky
    run_state.golden("sky-open")
    run_state.click(left + 64, 280, delay=0.8)   # Skybox field
    run_state.golden("asset-picker-open", crop="no-console")
    run_state.click(modal_left + 430, 603, delay=0.6)  # Cancel

    # Env -> Water: the normal-texture field browses bitmaps/ and picking a file
    # must emit SetWaterParamsCommand carrying its VFS path.
    run_state.click(left + 182, EDITOR_BUTTON_Y, delay=0.7)   # Water
    run_state.click(left + 87, 873, delay=0.8)   # Normal texture
    run_state.golden("asset-picker-bitmaps", crop="no-console")

    run_state.click(modal_left + 50, 335, delay=0.5)   # first file cell
    run_state.golden("asset-picker-selected", crop="no-console")
    run_state.click(modal_left + 343, 603, delay=0.8)  # OK

    def is_bitmap(path: object) -> bool:
        return (
            isinstance(path, str)
            and path.startswith("bitmaps/")
            and "bitmaps/bitmaps" not in path
        )

    run_state.assert_command("SetWaterParamsCommand", normalTexture=is_bitmap)
    run_state.golden("asset-picked")


SCENARIOS = {
    "main_panel_tabs": main_panel_tabs,
    "all_editors": all_editors,
    "dialogs": dialogs,
    "notifications": notifications,
    "native_panel": native_panel,
}
