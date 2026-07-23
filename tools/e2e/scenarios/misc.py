"""Misc tab: Info, Teams."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.driver.utils.models import CommandValue, string_starts_with

from .helpers.geometry import (
    COLOR_PICKER,
    DIALOG,
    ENV_LIGHTING_COLORS,
    MISC,
    MISC_INFO_FIELDS,
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


@scenario(crop="right-panel")
def info_panel(run_state: "RunState") -> None:
    """Repro for the colour leaking into Misc -> Info (O6).

    Pick a colour in Env -> Lighting, then switch to Misc -> Info and type.
    """
    run_state.focus()
    left = panel_left(run_state)
    # Env -> Lighting, open the Diffuse colour swatch and confirm a colour.
    run_state.click(left + TAB_X["env"], TAB_Y, delay=Delay.MS_200)
    run_state.click(*editor_point(left, "env", "lighting"), delay=Delay.MS_400)
    run_state.click(*panel_point(left, ENV_LIGHTING_COLORS[0][1]), delay=Delay.MS_400)
    run_state.click(ENV_LIGHTING_COLORS[0][2], COLOR_PICKER["sample_y"], delay=Delay.MS_200)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok_compact"]), delay=Delay.MS_400)
    run_state.screenshot("after-color-pick")
    # Misc -> Info, then edit a text field.
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=Delay.MS_300)
    run_state.click(*editor_point(left, "misc", "info"), delay=Delay.MS_500)
    run_state.screenshot("info-open")
    for point, value in MISC_INFO_FIELDS:
        run_state.fill_text(*panel_point(left, point), value, click_delay=Delay.MS_150, commit_delay=Delay.MS_300)
        run_state.assert_any_command("SetScenarioInfoCommand")
    run_state.assert_any_command(
        "SetScenarioInfoCommand",
        data=_scenario_info_matches,
    )
    run_state.screenshot("info-edited")


@scenario(crop="right-panel")
def teams_panel(run_state: "RunState") -> None:
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=Delay.MS_200)
    run_state.screenshot("misc-tab")
    run_state.click(*editor_point(left, "misc", "teams"), delay=Delay.MS_500)
    run_state.screenshot("teams-open")
    run_state.click(*panel_point(left, MISC["team_add"]), delay=Delay.MS_800)
    run_state.assert_any_command(
        "AddTeamCommand",
        name=string_starts_with("New team:"),
    )
    run_state.screenshot("team-added")
    # Edit the first player team. Fields live in a modal, not in every row.
    run_state.click(*panel_point(left, MISC["team_edit_first"]), delay=Delay.MS_800)
    run_state.screenshot_root("team-edit-dialog")
    run_state.click(*dialog_point(run_state, DIALOG["team_name"]), delay=Delay.MS_200)
    run_state.key("ctrl+a", delay=Delay.MS_100)
    run_state.type_text("Blue Team")
    run_state.click(*dialog_point(run_state, DIALOG["team_ai"]), delay=Delay.MS_200)
    for point, value in TEAM_NUMBERS:
        run_state.click(*dialog_point(run_state, point), delay=Delay.MS_100)
        run_state.key("ctrl+a", delay=Delay.MS_80)
        run_state.type_text(value)
    run_state.click(*dialog_point(run_state, DIALOG["team_color"]), delay=Delay.MS_300)
    run_state.screenshot_root("team-color-picker-open")
    run_state.click(*dialog_point(run_state, COLOR_PICKER["team_hue"]), delay=Delay.MS_120)
    run_state.click(COLOR_PICKER["team_sample_x"], COLOR_PICKER["sample_y"], delay=Delay.MS_150)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok_compact"]), delay=Delay.MS_500)
    run_state.screenshot_root("team-color-picker-closed")
    run_state.click(*dialog_point(run_state, DIALOG["team_ok"]), delay=Delay.MS_800)
    run_state.assert_any_command(
        "UpdateTeamCommand",
        team=_team_update_matches,
    )
    run_state.screenshot("team-updated")
    run_state.click(*panel_point(left, MISC["team_remove_first"]), delay=Delay.MS_800)
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
