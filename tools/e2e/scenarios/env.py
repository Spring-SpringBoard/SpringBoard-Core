"""Env tab: Lighting, Sky, Water."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import EDITOR_BUTTON_Y, TAB_X, TAB_Y, panel_left

if TYPE_CHECKING:
    from runner import E2ERun


def lighting_panel(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.18)
    run_state.screenshot("env-tab")
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.35)
    run_state.screenshot("lighting-open")
    shadow_mode_y = 207
    run_state.move(left + 180, shadow_mode_y, delay=0.12)
    run_state.screenshot("shadow-mode-hover")
    run_state.click(left + 180, shadow_mode_y, delay=0.12)
    run_state.screenshot("shadow-mode-open")
    # Hover an option in the open dropdown to check spacing + hover feedback.
    run_state.move(left + 180, shadow_mode_y + 60, delay=0.2)
    run_state.screenshot("shadow-option-hover")
    run_state.key("Down", delay=0.12)
    run_state.key("Return", delay=0.25)
    run_state.screenshot("shadow-mode-change")
    sun_dir_y = 244
    sun_dir_x = 92
    run_state.click(left + sun_dir_x, sun_dir_y, delay=0.08)
    run_state.screenshot("sun-dir-x-editing")
    run_state.key_chord(("ctrl",), "a")
    run_state.type_text("0.25")
    run_state.key("Return", delay=0.25)
    run_state.screenshot("sun-dir-x-edit")
    run_state.drag(left + sun_dir_x, sun_dir_y, left + sun_dir_x + 160, sun_dir_y)
    run_state.screenshot("sun-dir-x-drag")
    run_state.click(left + 110, 310, delay=0.25)
    run_state.screenshot_root("color-picker-open-root")
    run_state.click_root(1160, 690, delay=0.15)
    run_state.screenshot_root("color-picker-map-click-root")
    # Drag across the SV square: the marker and colour must follow the cursor.
    run_state.drag_root(1160, 690, 1240, 620)
    run_state.screenshot_root("color-picker-map-drag-root")
    # Confirm with OK, then re-open the swatch: after OK the editor's colour
    # control must still be clickable (O5).
    run_state.click_root(1319, 899, delay=0.4)
    run_state.screenshot("after-color-ok")
    run_state.click(left + 110, 310, delay=0.4)
    run_state.screenshot_root("color-picker-reopen-root")
    # Drag the dialog by its header: it must move (O1).
    run_state.drag_root(1150, 565, 1000, 470)
    run_state.screenshot_root("color-picker-dragged-root")


SCENARIOS = {
    "lighting_panel": lighting_panel,
}
