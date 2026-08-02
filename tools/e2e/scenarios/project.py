"""Project creation and persistence workflow steps."""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from e2e.driver.state import RunState


def _project_round_trip(run_state: "RunState") -> None:
    """Create a project, then reopen it through Load."""
    new_project = run_state.control.dialog("new_project").open()
    new_project.set("name", "RoundTrip")
    create_log = run_state.log_cursor()
    create_commands = run_state.command_cursor()
    new_project.accept()
    run_state.wait_for_command("ReloadIntoProjectCommand", after=create_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=create_log)

    load = run_state.control.dialog("load_project").open()
    run_state.control_capture("load-lists-project")
    load.select("springboard/projects/RoundTrip.sdd")
    load_log = run_state.log_cursor()
    load_commands = run_state.command_cursor()
    load.accept()
    run_state.wait_for_command("ReloadIntoProjectCommand", after=load_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=load_log)
    run_state.assert_command_at_least("ReloadIntoProjectCommand", 2)
    run_state.control_capture("after-load")


def _project_save_as(run_state: "RunState") -> None:
    """Save the current project under a new name and reload into it."""
    save_as = run_state.control.dialog("save_project_as").open()
    run_state.control_capture("save-as-open")
    save_as.set("name", "SavedProj")
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    save_as.accept()
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)
    for name in ("SetProjectNamePathCommand", "SaveProjectInfoCommand", "SaveCommand", "ReloadIntoProjectCommand"):
        run_state.assert_command(name)
    run_state.control_capture("after-reload")


def _project_thumbnail(run_state: "RunState") -> None:
    """Save a project and verify its thumbnail appears in the Open dialog."""
    save_as = run_state.control.dialog("save_project_as").open()
    save_as.set("name", "ShotProj")
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    save_as.accept()
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)
    run_state.control.dialog("load_project").open()
    run_state.control_capture("open-with-thumbnail")


def _large_map_create(run_state: "RunState") -> None:
    """Create the largest map the dialog allows and boot into it."""
    new_project = run_state.control.dialog("new_project").open()
    new_project.set("name", "BigMap")
    new_project.set("size_x", 32)
    new_project.set("size_y", 32)
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    new_project.accept()
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)
    for name in ("SaveProjectInfoCommand", "ReloadIntoProjectCommand", "LoadProjectCommand"):
        run_state.assert_command(name)
    run_state.control_capture("big-map-loaded")
