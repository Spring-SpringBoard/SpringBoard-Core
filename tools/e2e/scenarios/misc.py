"""Misc tab: Info, Teams."""

from typing import TYPE_CHECKING

from .geometry import (
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
from .registry import scenario

if TYPE_CHECKING:
    from ..runner import E2ERun
else:
    from ..run_state import RunState as E2ERun


@scenario(uis=("rmlui", "rust"), crop="right-panel")
def info_panel(run_state: E2ERun) -> None:
    """Repro for the colour leaking into Misc -> Info (O6).

    Pick a colour in Env -> Lighting, then switch to Misc -> Info and type.
    """
    run_state.focus()
    left = panel_left(run_state)
    # Env -> Lighting, open the Diffuse colour swatch and confirm a colour.
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.2)
    run_state.click(*editor_point(left, "env", "lighting"), delay=0.4)
    run_state.click(*panel_point(left, ENV_LIGHTING_COLORS[0][1]), delay=0.4)
    run_state.click(ENV_LIGHTING_COLORS[0][2], COLOR_PICKER["sample_y"], delay=0.2)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok_compact"]), delay=0.4)
    run_state.screenshot("after-color-pick")
    # Misc -> Info, then edit a text field.
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.3)
    run_state.click(*editor_point(left, "misc", "info"), delay=0.5)
    run_state.screenshot("info-open")
    for point, value in MISC_INFO_FIELDS:
        run_state.fill_text(*panel_point(left, point), value, click_delay=0.15, commit_delay=0.3)
        run_state.assert_any_command("SetScenarioInfoCommand")
    run_state.assert_any_command(
        "SetScenarioInfoCommand",
        data=lambda value: (
            isinstance(value, dict)
            and value
            == {
                "name": "Verified Scenario",
                "description": "All metadata fields",
                "version": "2.5",
                "author": "Native UI",
            }
        ),
    )
    run_state.screenshot("info-edited")


@scenario(uis=("chili", "rmlui", "rust"), crop="right-panel")
def teams_panel(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.2)
    run_state.screenshot("misc-tab")
    run_state.click(*editor_point(left, "misc", "teams"), delay=0.5)
    run_state.screenshot("teams-open")
    run_state.click(*panel_point(left, MISC["team_add"]), delay=0.8)
    run_state.assert_any_command(
        "AddTeamCommand",
        name=lambda value: isinstance(value, str) and value.startswith("New team:"),
    )
    run_state.screenshot("team-added")
    # Edit the first player team. Fields live in a modal, not in every row.
    run_state.click(*panel_point(left, MISC["team_edit_first"]), delay=0.8)
    run_state.screenshot_root("team-edit-dialog")
    run_state.click(*dialog_point(run_state, DIALOG["team_name"]), delay=0.2)
    run_state.key("ctrl+a", delay=0.1)
    run_state.type_text("Blue Team")
    run_state.click(*dialog_point(run_state, DIALOG["team_ai"]), delay=0.2)
    for point, value in TEAM_NUMBERS:
        run_state.click(*dialog_point(run_state, point), delay=0.1)
        run_state.key("ctrl+a", delay=0.08)
        run_state.type_text(value)
    run_state.click(*dialog_point(run_state, DIALOG["team_color"]), delay=0.3)
    run_state.screenshot_root("team-color-picker-open")
    run_state.click(*dialog_point(run_state, COLOR_PICKER["team_hue"]), delay=0.12)
    run_state.click(COLOR_PICKER["team_sample_x"], COLOR_PICKER["sample_y"], delay=0.15)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok_compact"]), delay=0.5)
    run_state.screenshot_root("team-color-picker-closed")
    run_state.click(*dialog_point(run_state, DIALOG["team_ok"]), delay=0.8)
    run_state.assert_any_command(
        "UpdateTeamCommand",
        team=lambda value: (
            isinstance(value, dict)
            and value.get("name") == "Blue Team"
            and value.get("ai") is True
            and value.get("metal") == 125.0
            and value.get("energyMax") == 750.0
            and isinstance(value.get("color"), dict)
            and value["color"].get("r", 0) > 0.2
        ),
    )
    run_state.screenshot("team-updated")
    run_state.click(*panel_point(left, MISC["team_remove_first"]), delay=0.8)
    run_state.assert_any_command("RemoveTeamCommand")
    run_state.screenshot("team-removed")
