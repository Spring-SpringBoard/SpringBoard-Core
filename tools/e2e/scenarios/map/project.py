"""Map project export and round-trip scenarios."""

import shutil
from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.geometry import (
    DIALOG,
    MAP,
    MAP_ACTIONS,
    PARK_PANEL,
    TAB_X,
    TAB_Y,
    TOOLBAR,
    dialog_point,
    dropdown_option,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)

from .common import _sweep, _wait_for_archive

if TYPE_CHECKING:
    from e2e.driver.state import RunState


def _save_project(run_state: "RunState", name: str) -> None:
    """Save a named project through the typed control command."""
    assert run_state.write_dir is not None
    path = run_state.write_dir / "springboard" / "projects" / f"{name}.sdd"
    save_log = run_state.log_cursor()
    run_state.control.commands["SaveCommand"](path=str(path), isNewProject=False)
    run_state.control.wait_for_update()
    run_state.assert_command_at_least("SaveCommand", 1)
    run_state.wait_for_log("save editor state:", after=save_log)


def _map_export(run_state: "RunState") -> None:
    """The whole map pipeline: save a project, sculpt and paint the map, then
    compile it to a Spring archive.

    Save As establishes a project (Export needs its path); a Terrain/Add sweep
    reshapes the ground across the whole map, a texture sweep paints it, the
    project is saved through the control API, and Export -> Spring archive runs
    the bundled compiler. Asserts the sculpt/paint/export commands and that the
    compiled `.sdz` lands on disk.
    Deliberately fast -- the point is the pipeline runs end to end.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)

    # A project first: Export compiles the *saved* project, so it needs a path.
    # Save As creates it and reloads into it. Wait for the second ready line,
    # rather than assuming every machine needs the old fixed eight seconds.
    reload_log = run_state.log_cursor()
    run_state.click_settled(*panel_point(left, TOOLBAR["save_as"]), delay=Delay.FRAME)
    run_state.fill_text(
        *dialog_point(run_state, DIALOG["file_name"]),
        "ExportMap",
        click_delay=Delay.INPUT,
        commit_delay=Delay.INPUT,
    )
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_ok_name"]), delay=Delay.INPUT)
    run_state.wait_for_command("ReloadIntoProjectCommand")
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)

    # Terrain: pick a pattern, arm Add, a fat brush, one sweep across the map.
    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.FRAME)
    terrain = run_state.control.editor("heightmapEditor")
    terrain.size = 1200.0
    terrain.strength = 10.0
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.CONTROL)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=Delay.CONTROL)
    _sweep(run_state, left, width, height)
    run_state.assert_command_at_least("TerrainShapeModifyCommand", 1)

    # Texture: choose a material, pick a brush shape, paint across the map.
    run_state.click(*editor_point(left, "map", "texture"), delay=Delay.FRAME)
    run_state.click(*panel_point(left, MAP["saved_brush_add"]), delay=Delay.SETTLE)
    run_state.click(*dialog_point(run_state, DIALOG["asset_core_cell"]), delay=Delay.FRAME)
    run_state.click(*panel_point(left, MAP["saved_brush_rect"]), delay=Delay.CONTROL)
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.CONTROL)
    _sweep(run_state, left, width, height)
    run_state.assert_any_command("TerrainChangeTextureCommand", paintMode="paint")
    run_state.key("Escape", delay=Delay.CONTROL)
    run_state.move(*panel_point(left, PARK_PANEL), delay=Delay.CONTROL)
    edited = run_state.screenshot("edited-before-export")

    # Save the edits, then Export -> Spring archive (the default type).
    _save_project(run_state, "ExportMap")
    run_state.click_settled(*panel_point(left, TOOLBAR["export"]), delay=Delay.CONTROL)
    run_state.fill_text(
        *dialog_point(run_state, DIALOG["file_name"]),
        "ExportMap",
        click_delay=Delay.INPUT,
        commit_delay=Delay.INPUT,
    )
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_ok_export"]), delay=Delay.INPUT)
    run_state.wait_for_command("ExportSpringArchiveCommand")
    run_state.assert_command("ExportSpringArchiveCommand")

    archive = _wait_for_archive(run_state, "ExportMap")
    if archive is None:
        raise AssertionError("export did not produce a .sdz archive")
    if archive.stat().st_size < 1024:
        raise AssertionError(f"compiled archive is suspiciously small: {archive}")

    # Prove the deliverable is usable: expose this session's archive to the map
    # scanner, create a project on it, and check that the painted material is
    # still visibly present.  Comparing camera frames pixel-for-pixel here is
    # deliberately avoided: reloading rebuilds the terrain draw and its
    # sub-pixel shading is not frame-stable, even when the exported texture is.
    # Under the test map's lighting `tiles` renders as slate grey while the base
    # map is green. That makes this a direct visual assertion that its diffuse
    # PNG made it through mapcompile and back in.
    map_region = (left // 2 - 260, height // 2 - 220, 520, 440)
    painted_before = run_state.count_color(edited, map_region, "#878692")
    if painted_before < 50:
        raise AssertionError(f"texture paint was not visibly present before export ({painted_before} tile pixels)")
    assert run_state.write_dir is not None
    maps_dir = run_state.write_dir / "maps"
    maps_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(archive, maps_dir / "ExportMap.sdz")
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    run_state.click_settled(*panel_point(left, TOOLBAR["new_project"]), delay=Delay.CONTROL)
    run_state.click_settled(*dialog_point(run_state, DIALOG["new_project_name"]), delay=Delay.INPUT)
    run_state.type_text("FromExport")
    run_state.click_settled(*dialog_point(run_state, DIALOG["new_project_map"]), delay=Delay.CONTROL)
    run_state.click_settled(
        *dialog_point(run_state, dropdown_option(DIALOG["new_project_map"], 1)), delay=Delay.CONTROL
    )
    run_state.click_settled(*dialog_point(run_state, DIALOG["new_project_create_nosize"]), delay=Delay.INPUT)
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)
    reopened = run_state.screenshot("export-reopened")
    painted_after = run_state.count_color(reopened, map_region, "#878692")
    if painted_after < 50:
        raise AssertionError(f"exported map lost its painted diffuse texture ({painted_after} tile pixels)")
    if abs(painted_after - painted_before) > painted_before // 5:
        raise AssertionError(
            "exported diffuse texture moved within the map: "
            f"{painted_before} tile pixels before export, {painted_after} after reopening"
        )


def _map_roundtrip(run_state: "RunState") -> None:
    """Full round-trip: sculpt/paint a map, export it, then start a new project
    ON that exported map and confirm the terrain came through.

    Exercises the whole pipeline plus the piece that was blocked until the
    ScanAllDirs binding: an archive exported this session becomes selectable in
    New Project without a restart (available_maps rescans first).
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    # A central patch of the map (left of the 500-wide panel) to compare terrain.
    map_region = (left // 2 - 260, height // 2 - 220, 520, 440)
    original = run_state.screenshot("original-map")

    # Save As establishes a project; then sculpt + paint so the map is distinct.
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    run_state.click_settled(*panel_point(left, TOOLBAR["save_as"]))
    run_state.fill_text(
        *dialog_point(run_state, DIALOG["file_name"]),
        "RoundTrip",
        click_delay=Delay.INPUT,
        commit_delay=Delay.INPUT,
    )
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_ok_name"]))
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.FRAME)
    terrain = run_state.control.editor("heightmapEditor")
    terrain.size = 1400.0
    terrain.strength = 10.0
    terrain.height = 300.0
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.CONTROL)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=Delay.CONTROL)
    # Two sweeps at a representative strength for pronounced, stable relief.
    _sweep(run_state, left, width, height)
    _sweep(run_state, left, width, height)
    run_state.assert_command_at_least("TerrainShapeModifyCommand", 1)

    run_state.click(*editor_point(left, "map", "texture"), delay=Delay.FRAME)
    run_state.click(*panel_point(left, MAP["saved_brush_add"]), delay=Delay.SETTLE)
    run_state.click(*dialog_point(run_state, DIALOG["asset_core_cell"]), delay=Delay.FRAME)
    run_state.click(*panel_point(left, MAP["saved_brush_rect"]), delay=Delay.CONTROL)
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.CONTROL)
    _sweep(run_state, left, width, height)
    run_state.assert_any_command("TerrainChangeTextureCommand", paintMode="paint")

    # Park the pointer before the export sequence. The export itself is checked
    # after reload against its distinctive painted tile colour below; a direct
    # pixel comparison across a project reload is invalid because the camera
    # frame is rebuilt.
    run_state.move(*panel_point(left, PARK_PANEL))

    # Give the map a unique scenario name so the export does not collide with the
    # default "Manual's Scenario". "AAA ..." sorts first, making it dropdown index 1.
    scenario_info = run_state.control.editor("scenarioInfoView")
    scenario_info.set("name", "AAA RoundTrip")

    _save_project(run_state, "RoundTrip")
    run_state.click_settled(*panel_point(left, TOOLBAR["export"]))
    run_state.fill_text(
        *dialog_point(run_state, DIALOG["file_name"]),
        "RoundTrip",
        click_delay=Delay.INPUT,
        commit_delay=Delay.INPUT,
    )
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_ok_export"]))
    run_state.wait_for_command("ExportSpringArchiveCommand")
    run_state.assert_command("ExportSpringArchiveCommand")

    archive = _wait_for_archive(run_state, "RoundTrip")
    if archive is None:
        raise AssertionError("export did not produce a .sdz archive")

    # Install it where the archive scanner will find it as a map.
    assert run_state.write_dir is not None
    maps_dir = run_state.write_dir / "maps"
    maps_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(archive, maps_dir / "RoundTrip.sdz")
    # New Project must now list the just-exported map (available_maps rescans).
    run_state.click_settled(*panel_point(left, TOOLBAR["new_project"]))
    # Name first, while the dialog still has its full layout.
    run_state.fill_text(
        *dialog_point(run_state, DIALOG["new_project_name"]),
        "FromExport",
        click_delay=Delay.INPUT,
        commit_delay=Delay.INPUT,
    )
    # Open the map dropdown and pick the exported map. Its map name comes from the
    # scenario ("Manual's Scenario 1"), which sorts to option index 1 -- ahead of
    # the "RoundTrip 1.0" *project* entry, whose base map is flat.
    run_state.click_settled(*dialog_point(run_state, DIALOG["new_project_map"]))
    run_state.screenshot_root("roundtrip-map-dropdown")
    run_state.click_settled(*dialog_point(run_state, dropdown_option(DIALOG["new_project_map"], 1)))
    # Picking a non-blank map hides the Size row, so Create sits one row higher.
    run_state.screenshot_root("roundtrip-after-map")
    reload_log = run_state.log_cursor()
    reload_commands = run_state.command_cursor()
    run_state.click_settled(*dialog_point(run_state, DIALOG["new_project_create_nosize"]))
    run_state.wait_for_command("ReloadIntoProjectCommand", after=reload_commands)
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)

    roundtrip = run_state.screenshot("roundtrip-loaded")
    # The compiled terrain came through: sharply different from the flat default
    # it started on...
    run_state.assert_region_pixels(original, roundtrip, map_region, min_changed=20_000)
    # ...and it retains the distinctive slate tile diffuse texture used for the
    # paint stroke. This is stable across the reload's new camera frame, unlike
    # comparing two arbitrary terrain screenshots pixel-for-pixel.
    painted = run_state.count_color(roundtrip, map_region, "#878692")
    if painted < 50:
        raise AssertionError(f"round-trip export lost its painted diffuse texture ({painted} tile pixels)")
