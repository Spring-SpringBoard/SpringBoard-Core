"""Misc tab: Info, Teams."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import ACTION_Y, EDITOR_BUTTON_Y, TAB_X, TAB_Y, dialog_left, panel_left

if TYPE_CHECKING:
    from runner import E2ERun


def info_panel(run_state: E2ERun) -> None:
    """Repro for the colour leaking into Misc -> Info (O6).

    Pick a colour in Env -> Lighting, then switch to Misc -> Info and type.
    """
    run_state.focus()
    left = panel_left(run_state)
    # Env -> Lighting, open the Diffuse colour swatch and confirm a colour.
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.2)
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.4)
    run_state.click(left + 110, 310, delay=0.4)
    run_state.click(900, 300, delay=0.2)
    run_state.click(1138, 473, delay=0.4)
    run_state.screenshot("after-color-pick")
    # Misc -> Info, then edit a text field.
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.3)
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.5)
    run_state.screenshot("info-open")
    for y, value in (
        (190, "Verified Scenario"),
        (233, "All metadata fields"),
        (276, "2.5"),
        (318, "Native UI"),
    ):
        run_state.click(left + 200, y, delay=0.15)
        run_state.key("ctrl+a", delay=0.08)
        run_state.type_text(value)
        run_state.key("Return", delay=0.3)
        run_state.assert_any_command("SetScenarioInfoCommand")
    run_state.assert_any_command(
        "SetScenarioInfoCommand",
        data=lambda value: isinstance(value, dict)
        and value == {
            "name": "Verified Scenario",
            "description": "All metadata fields",
            "version": "2.5",
            "author": "Native UI",
        },
    )
    run_state.screenshot("info-edited")


def teams_panel(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.2)
    run_state.screenshot("misc-tab")
    run_state.click(left + 110, EDITOR_BUTTON_Y, delay=0.5)   # Teams (order 1)
    run_state.screenshot("teams-open")
    run_state.click(left + 38, ACTION_Y, delay=0.8)
    run_state.assert_any_command(
        "AddTeamCommand",
        name=lambda value: isinstance(value, str) and value.startswith("New team:"),
    )
    run_state.screenshot("team-added")
    # Edit the first player team. Fields live in a modal, not in every row.
    run_state.click(left + 425, 313, delay=0.8)
    run_state.screenshot_root("team-edit-dialog")
    modal = dialog_left(run_state)
    run_state.click(modal + 292, 269, delay=0.2)
    run_state.key("ctrl+a", delay=0.1)
    run_state.type_text("Blue Team")
    run_state.click(modal + 150, 304, delay=0.2)       # AI
    for x, y, value in (
        (120, 350, "125"),
        (260, 350, "500"),
        (120, 416, "250"),
        (260, 416, "750"),
        (120, 501, "100"),
        (260, 501, "200"),
    ):
        run_state.click(modal + x, y, delay=0.1)
        run_state.key("ctrl+a", delay=0.08)
        run_state.type_text(value)
    run_state.click(modal + 153, 459, delay=0.3)
    run_state.screenshot_root("team-color-picker-open")
    run_state.click(1010, 255, delay=0.12)
    run_state.click(900, 300, delay=0.15)
    run_state.click(1138, 473, delay=0.5)
    run_state.screenshot_root("team-color-picker-closed")
    run_state.click(modal + 472, 609, delay=0.8)
    run_state.assert_any_command(
        "UpdateTeamCommand",
        team=lambda value: isinstance(value, dict)
        and value.get("name") == "Blue Team"
        and value.get("ai") is True
        and value.get("metal") == 125.0
        and value.get("energyMax") == 750.0
        and isinstance(value.get("color"), dict)
        and value["color"].get("r", 0) > 0.2,
    )
    run_state.screenshot("team-updated")
    run_state.click(left + 468, 347, delay=0.8)
    run_state.assert_any_command("RemoveTeamCommand")
    run_state.screenshot("team-removed")


SCENARIOS = {
    "info_panel": info_panel,
    "teams_panel": teams_panel,
}
