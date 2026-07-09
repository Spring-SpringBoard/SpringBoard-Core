from __future__ import annotations

from typing import TYPE_CHECKING

from x11 import window_geometry

if TYPE_CHECKING:
    from runner import E2ERun


def run_scenario(run_state: E2ERun) -> None:
    if run_state.case.scenario == "chonsole_editing":
        chonsole_editing(run_state)
    elif run_state.case.scenario == "main_panel_tabs":
        main_panel_tabs(run_state)
    elif run_state.case.scenario == "lighting_panel":
        lighting_panel(run_state)
    elif run_state.case.scenario == "units_panel":
        units_panel(run_state)
    elif run_state.case.scenario == "texture_panel":
        texture_panel(run_state)
    elif run_state.case.scenario == "dev_console":
        dev_console(run_state)
    elif run_state.case.scenario == "teams_panel":
        teams_panel(run_state)
    else:
        raise ValueError(f"unknown scenario: {run_state.case.scenario}")


def chonsole_editing(run_state: E2ERun) -> None:
    run_state.focus()
    run_state.key("Escape", delay=0.08)
    run_state.key("Return", delay=0.18)
    run_state.screenshot("chonsole-open")
    run_state.type_text("/he")
    run_state.screenshot("suggestions")
    run_state.key_chord(("ctrl",), "a")
    run_state.type_text("alpha beta gamma")
    run_state.key_chord(("ctrl",), "Left")
    run_state.key_chord(("ctrl",), "Left")
    run_state.type_text("_")
    run_state.key("End")
    run_state.type_text("!")
    run_state.screenshot("navigation")
    run_state.key_chord(("ctrl", "shift"), "Left")
    run_state.screenshot("select-word")
    run_state.type_text("WORLD")
    run_state.screenshot("replace-selection")
    run_state.key_chord(("ctrl",), "a")
    run_state.screenshot("select-all")
    run_state.type_text("/help")
    run_state.key("Return", delay=0.25)
    run_state.screenshot("execute-help")


def main_panel_tabs(run_state: E2ERun) -> None:
    run_state.focus()
    assert run_state.window is not None
    width, _height = window_geometry(run_state.window)
    panel_left = width - 500
    tabs = (
        ("objects", 42),
        ("map", 110),
        ("env", 180),
        ("misc", 300),
    )
    for name, offset_x in tabs:
        run_state.click(panel_left + offset_x, 35, delay=0.18)
        run_state.screenshot(f"tab-{name}")


def units_panel(run_state: E2ERun) -> None:
    run_state.focus()
    assert run_state.window is not None
    width, _height = window_geometry(run_state.window)
    panel_left = width - 500
    toolbox_y = 88
    # Objects tab is the default tab; click it to be safe.
    run_state.click(panel_left + 42, 35, delay=0.2)
    run_state.screenshot("objects-tab")
    # First toolbox button is Units (order 0).
    run_state.click(panel_left + 38, toolbox_y, delay=0.4)
    run_state.screenshot("units-open")
    # Second toolbox button is Features.
    run_state.click(panel_left + 110, toolbox_y, delay=0.4)
    run_state.screenshot("features-open")
    # Click several grid items in sequence to exercise selection -> state
    # rebuild repeatedly (this is where use-after-free crashes show up).
    for col in (55, 140, 225, 310, 55, 140):
        run_state.click(panel_left + col, 470, delay=0.25)
    run_state.screenshot("features-item-click")
    # Type in the search box to exercise filtering (and the old search crash).
    run_state.click(panel_left + 180, 400, delay=0.15)
    run_state.type_text("tree")
    run_state.screenshot("features-search")


def teams_panel(run_state: E2ERun) -> None:
    run_state.focus()
    assert run_state.window is not None
    width, _height = window_geometry(run_state.window)
    panel_left = width - 500
    toolbox_y = 88
    run_state.click(panel_left + 300, 35, delay=0.2)  # Misc tab
    run_state.screenshot("misc-tab")
    run_state.click(panel_left + 110, toolbox_y, delay=0.5)  # Teams (order 1)
    run_state.screenshot("teams-open")
    # "Add" action button (the action row sits below the toolbox+action bar,
    # around y=217). Adding repeatedly rebuilds the team list DOM, which is
    # where the use-after-free on stale elements showed up.
    for _ in range(3):
        run_state.click(panel_left + 38, 217, delay=0.4)
    run_state.screenshot("teams-added")


def dev_console(run_state: E2ERun) -> None:
    run_state.focus()
    # The console is visible by default; capture it, then F8 toggles it away.
    run_state.screenshot("dev-console-open")
    run_state.key("F8", delay=0.6)
    run_state.screenshot("dev-console-hidden")


def texture_panel(run_state: E2ERun) -> None:
    run_state.focus()
    assert run_state.window is not None
    width, _height = window_geometry(run_state.window)
    panel_left = width - 500
    toolbox_y = 88
    # Map tab.
    run_state.click(panel_left + 110, 35, delay=0.2)
    run_state.screenshot("map-tab")
    # Texture editor is toolbox order 1 (second button).
    run_state.click(panel_left + 110, toolbox_y, delay=0.5)
    run_state.screenshot("texture-open")


def lighting_panel(run_state: E2ERun) -> None:
    run_state.focus()
    assert run_state.window is not None
    width, _height = window_geometry(run_state.window)
    panel_left = width - 500
    lighting_button_y = 88
    run_state.click(panel_left + 180, 35, delay=0.18)
    run_state.screenshot("env-tab")
    run_state.click(panel_left + 38, lighting_button_y, delay=0.35)
    run_state.screenshot("lighting-open")
    shadow_mode_y = 207
    run_state.move(panel_left + 180, shadow_mode_y, delay=0.12)
    run_state.screenshot("shadow-mode-hover")
    run_state.click(panel_left + 180, shadow_mode_y, delay=0.12)
    run_state.screenshot("shadow-mode-open")
    # Hover an option in the open dropdown to check spacing + hover feedback.
    run_state.move(panel_left + 180, shadow_mode_y + 60, delay=0.2)
    run_state.screenshot("shadow-option-hover")
    run_state.key("Down", delay=0.12)
    run_state.key("Return", delay=0.25)
    run_state.screenshot("shadow-mode-change")
    sun_dir_y = 244
    sun_dir_x = 92
    run_state.click(panel_left + sun_dir_x, sun_dir_y, delay=0.08)
    run_state.screenshot("sun-dir-x-editing")
    run_state.key_chord(("ctrl",), "a")
    run_state.type_text("0.25")
    run_state.key("Return", delay=0.25)
    run_state.screenshot("sun-dir-x-edit")
    run_state.drag(panel_left + sun_dir_x, sun_dir_y, panel_left + sun_dir_x + 160, sun_dir_y)
    run_state.screenshot("sun-dir-x-drag")
    run_state.click(panel_left + 110, 310, delay=0.25)
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
    run_state.click(panel_left + 110, 310, delay=0.4)
    run_state.screenshot_root("color-picker-reopen-root")
