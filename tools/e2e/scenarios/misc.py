"""Misc domain scenarios and the Teams interaction contract."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.driver.utils.models import CommandValue, string_starts_with

from .helpers.geometry import (
    COLOR_PICKER,
    DIALOG,
    MISC,
    TAB_X,
    TAB_Y,
    TEAM_NUMBERS,
    dialog_point,
    editor_point,
    panel_left,
    panel_point,
)
from .helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario()
def info_panel(run_state: "RunState") -> None:
    """Scenario metadata commits as domain state, without text-widget input."""
    editor = run_state.control.editor("scenarioInfoView")
    values = {
        "name": "Verified Scenario",
        "description": "All metadata fields",
        "version": "2.5",
        "author": "Native UI",
    }
    for field, value in values.items():
        setattr(editor, field, value)
        run_state.assert_any_command("SetScenarioInfoCommand")
    run_state.assert_any_command(
        "SetScenarioInfoCommand",
        data=_scenario_info_matches,
    )
    # `name` is also a property of the Editor handle itself, so use the
    # collision-safe explicit getter for every field in this model.
    assert {field: editor.get(field) for field in values} == values


@scenario(crop="right-panel")
def teams_panel(run_state: "RunState") -> None:
    """Team-row and edit-dialog interaction.

    Team add/select/edit is deliberately still X11 coverage until the control
    API grows a typed team-domain handle.  It is not a model for editor-domain
    tests: the test's contract is the row/modal interaction itself.
    """
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=Delay.CONTROL)
    run_state.screenshot("misc-tab")
    run_state.click(*editor_point(left, "misc", "teams"), delay=Delay.DIALOG)
    run_state.screenshot("teams-open")
    run_state.click(*panel_point(left, MISC["team_add"]), delay=Delay.READY)
    run_state.assert_any_command(
        "AddTeamCommand",
        name=string_starts_with("New team:"),
    )
    run_state.screenshot("team-added")
    # Edit the first player team. Fields live in a modal, not in every row.
    run_state.click(*panel_point(left, MISC["team_edit_first"]), delay=Delay.READY)
    run_state.screenshot_root("team-edit-dialog")
    run_state.click(*dialog_point(run_state, DIALOG["team_name"]), delay=Delay.CONTROL)
    run_state.key("ctrl+a", delay=Delay.INPUT)
    run_state.type_text("Blue Team")
    run_state.click(*dialog_point(run_state, DIALOG["team_ai"]), delay=Delay.CONTROL)
    for point, value in TEAM_NUMBERS:
        run_state.click(*dialog_point(run_state, point), delay=Delay.INPUT)
        run_state.key("ctrl+a", delay=Delay.INPUT)
        run_state.type_text(value)
    run_state.click(*dialog_point(run_state, DIALOG["team_color"]), delay=Delay.FRAME)
    run_state.screenshot_root("team-color-picker-open")
    run_state.click(*dialog_point(run_state, COLOR_PICKER["team_hue"]), delay=Delay.CONTROL)
    run_state.click(COLOR_PICKER["team_sample_x"], COLOR_PICKER["sample_y"], delay=Delay.CONTROL)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok_compact"]), delay=Delay.DIALOG)
    run_state.screenshot_root("team-color-picker-closed")
    run_state.click(*dialog_point(run_state, DIALOG["team_ok"]), delay=Delay.READY)
    run_state.assert_any_command(
        "UpdateTeamCommand",
        team=_team_update_matches,
    )
    run_state.screenshot("team-updated")
    run_state.click(*panel_point(left, MISC["team_remove_first"]), delay=Delay.READY)
    run_state.assert_any_command("RemoveTeamCommand")
    run_state.screenshot("team-removed")


def _scenario_info_matches(value: CommandValue) -> bool:
    return value == {
        "name": "Verified Scenario",
        "description": "All metadata fields",
        "version": "2.5",
        "author": "Native UI",
    }


def _team_update_matches(value: CommandValue) -> bool:
    if not isinstance(value, dict):
        return False
    color = value.get("color")
    red = color.get("r") if isinstance(color, dict) else None
    return (
        value.get("name") == "Blue Team"
        and value.get("ai") is True
        and value.get("metal") == 125.0
        and value.get("energyMax") == 750.0
        and isinstance(red, int | float)
        and red > 0.2
    )
