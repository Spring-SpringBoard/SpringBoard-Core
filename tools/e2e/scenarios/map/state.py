"""Map editor-state save and reload scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.driver.utils.models import is_object
from e2e.scenarios.helpers.geometry import (
    DIALOG,
    MAP,
    MAP_ACTIONS,
    TAB_X,
    TAB_Y,
    TOOLBAR,
    dialog_point,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)

from .common import TERRAIN_PATTERN_PATH

if TYPE_CHECKING:
    from e2e.driver.state import RunState


def _editor_state_roundtrip(run_state: "RunState") -> None:
    """Save brush/editor state, reload it, then paint with the restored data.

    The check deliberately uses the first commands *after* loading as a guard:
    hydrating fields and grids must not emit editing commands. A Terrain Set
    dab and a texture Paint dab then prove the restored values are the ones
    that reach the tools, including the saved material brush.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    point = (width // 3, height // 2)

    # Set a representative cross-section of the shared terrain brush fields.
    # Save As below writes those values and reloads into the new project.
    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.SETTLE)
    terrain = run_state.control.editor("heightmapEditor")
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.CONTROL)
    terrain.size = 333.0
    terrain.rotation = 27.0
    terrain.strength = 8.5
    terrain.height = 44.0
    terrain.applyDir = "Only Lower"

    # Create one texture preset. Brush geometry is deliberately per editor, so
    # seed the texture editor's own size before capturing its material. The
    # preset must retain these values through the tab switch and project reload.
    run_state.click(*editor_point(left, "map", "texture"), delay=Delay.SETTLE)
    texture = run_state.control.editor("textureEditor")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.CONTROL)
    texture.size = 333.0
    texture.texScale = 3.5
    texture.specularEnabled = False
    run_state.click(*panel_point(left, MAP["saved_brush_add"]), delay=Delay.SETTLE)
    run_state.click(*dialog_point(run_state, DIALOG["asset_core_cell"]), delay=Delay.SETTLE)

    # Save As writes this state, then reloads into the project. No screenshot is
    # needed: the command payloads below are stronger evidence and keep this
    # regression test quick. The reload's own project/bootstrap commands are
    # expected; editor-state hydration must add nothing to that set.
    before_save = len(run_state.commands())
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    run_state.click_settled(*panel_point(left, TOOLBAR["save_as"]))
    run_state.click(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.CONTROL)
    run_state.type_text("EditorState")
    run_state.key("Return", delay=Delay.CONTROL)
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_ok_name"]))
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)
    # A project reload recreates the native module and its loopback server.
    # Reopen the typed client lazily when this scenario next needs an editor.
    run_state.close_control()

    after_load = run_state.commands()[before_save:]
    classes = [entry.get("data", {}).get("className") for entry in after_load]
    lifecycle = {
        "SetProjectNamePathCommand",
        "SaveProjectInfoCommand",
        "SaveCommand",
        "ReloadIntoProjectCommand",
        "SetGlobalLosCommand",
        "LoadProjectCommand",
    }
    unexpected = [name for name in classes if name not in lifecycle]
    if unexpected:
        raise AssertionError(
            f"loading editor state emitted editing commands; expected only project lifecycle commands, got {classes}"
        )
    for name in ("SaveCommand", "ReloadIntoProjectCommand", "LoadProjectCommand"):
        if name not in classes:
            raise AssertionError(f"save/load lifecycle omitted {name}: {classes}")

    # A fresh Terrain panel must use the saved values rather than its defaults.
    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.SETTLE)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_set"]), delay=Delay.CONTROL)
    before_terrain = run_state.assert_command_at_least("TerrainLevelCommand", 0)
    run_state.click(*point, delay=Delay.DIALOG)
    run_state.assert_command_at_least("TerrainLevelCommand", before_terrain + 1)
    run_state.assert_any_command(
        "TerrainLevelCommand",
        size=333.0,
        rotation=27.0,
        strength=8.5,
        height=44.0,
        applyDirID=-1,
        shapeName=TERRAIN_PATTERN_PATH,
    )

    # The saved brush grid is restored too. Selecting its first item and making
    # one dab proves the loaded material survives, not just the scalar fields.
    run_state.click(*editor_point(left, "map", "texture"), delay=Delay.SETTLE)
    run_state.click(*panel_point(left, MAP["saved_brush_first"]), delay=Delay.FRAME)
    run_state.screenshot("restored-editor-state")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.CONTROL)
    before_texture = run_state.assert_command_at_least("TerrainChangeTextureCommand", 0)
    run_state.click(*point, delay=Delay.DIALOG)
    run_state.assert_command_at_least("TerrainChangeTextureCommand", before_texture + 1)
    run_state.assert_any_command(
        "TerrainChangeTextureCommand",
        paintMode="paint",
        size=333.0,
        patternTexture=TERRAIN_PATTERN_PATH,
        texScale=3.5,
        specularEnabled=False,
        brushTexture=is_object,
    )
