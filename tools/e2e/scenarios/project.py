"""Project creation and persistence workflow steps."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.geometry import DIALOG, TOOLBAR, dialog_point, panel_left, panel_point

if TYPE_CHECKING:
    from e2e.driver.state import RunState


def _project_round_trip(run_state: "RunState") -> None:
    """Create a project, then reopen it through Load."""
    left = panel_left(run_state)
    run_state.focus()

    run_state.click_settled(*panel_point(left, TOOLBAR["new_project"]))
    run_state.click(*dialog_point(run_state, DIALOG["new_project_name"]), delay=Delay.CONTROL)
    run_state.type_text("RoundTrip")
    run_state.key("Return", delay=Delay.FRAME)
    create_log = run_state.log_cursor()
    create_commands = run_state.command_cursor()
    run_state.click_settled(*dialog_point(run_state, DIALOG["new_project_create"]))
    run_state.wait_for_command("ReloadIntoProjectCommand", after=create_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=create_log)

    run_state.click_settled(*panel_point(left, TOOLBAR["load"]))
    run_state.screenshot("load-lists-project")
    run_state.click(*dialog_point(run_state, DIALOG["file_first_cell"]), delay=Delay.DIALOG)
    load_log = run_state.log_cursor()
    load_commands = run_state.command_cursor()
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_ok"]))
    run_state.wait_for_command("ReloadIntoProjectCommand", after=load_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=load_log)
    run_state.assert_command_at_least("ReloadIntoProjectCommand", 2)
    run_state.screenshot("after-load")


def _project_save_as(run_state: "RunState") -> None:
    """Save the current project under a new name and reload into it."""
    left = panel_left(run_state)
    run_state.focus()
    run_state.click_settled(*panel_point(left, TOOLBAR["save_as"]))
    run_state.screenshot("save-as-open")
    run_state.click(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.FRAME)
    run_state.type_text("SavedProj")
    run_state.key("Return", delay=Delay.FRAME)
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_ok_name"]))
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)
    for name in ("SetProjectNamePathCommand", "SaveProjectInfoCommand", "SaveCommand", "ReloadIntoProjectCommand"):
        run_state.assert_command(name)
    run_state.move(1280, 700)
    run_state.screenshot("after-reload")


def _project_thumbnail(run_state: "RunState") -> None:
    """Save a project and verify its thumbnail appears in the Open dialog."""
    left = panel_left(run_state)
    run_state.focus()
    # Save As is created on the next RmlUi update after the toolbar click. Give
    # that modal one control boundary before typing; without it this step can
    # type into the underlying panel and then wait forever for a reload.
    run_state.click_settled(*panel_point(left, TOOLBAR["save_as"]), delay=Delay.DIALOG)
    run_state.click(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.CONTROL)
    run_state.type_text("ShotProj")
    run_state.key("Return", delay=Delay.FRAME)
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_ok_name"]))
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)
    run_state.click_settled(*panel_point(left, TOOLBAR["load"]))
    run_state.screenshot("open-with-thumbnail")


def _large_map_create(run_state: "RunState") -> None:
    """Create the largest map the dialog allows and boot into it."""
    left = panel_left(run_state)
    run_state.focus()
    run_state.click_settled(*panel_point(left, TOOLBAR["new_project"]))
    run_state.click(*dialog_point(run_state, DIALOG["new_project_name"]), delay=Delay.CONTROL)
    run_state.type_text("BigMap")
    run_state.key("Return", delay=Delay.FRAME)
    for field, value in (("new_project_size_x", "32"), ("new_project_size_y", "32")):
        run_state.fill_text(
            *dialog_point(run_state, DIALOG[field]),
            value,
            click_delay=Delay.CONTROL,
            commit_delay=Delay.FRAME,
        )
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    run_state.click_settled(*dialog_point(run_state, DIALOG["new_project_create"]))
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)
    for name in ("SaveProjectInfoCommand", "ReloadIntoProjectCommand", "LoadProjectCommand"):
        run_state.assert_command(name)
    run_state.screenshot("big-map-loaded")
