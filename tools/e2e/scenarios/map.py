"""Map tab: Terrain, Texture, Metal, Grass, Settings."""

import shutil
import time
from pathlib import Path
from typing import TYPE_CHECKING

from e2e.driver.timing import Delay, Timeout, pause
from e2e.driver.utils.models import is_object, list_first_is, string_contains

from .helpers.geometry import (
    DIALOG,
    MAP,
    MAP_ACTIONS,
    MAP_TERRAIN_BRUSHES,
    MAP_TEXTURE_ACTIONS,
    MISC,
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
from .helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState

TERRAIN_PATTERN_PATH = "springboard/assets/core/brush_patterns/terrain/circle1.png"

# A stroke holds the button down and sweeps. The brush waits out an initial delay
# (0.3s) before a *held* button starts repeating, then dabs on a timer -- so a
# quick drag is one dab and proves nothing about holding. These numbers keep the
# button down for roughly a second, which is several dabs.
STROKE_STEPS = 8
STROKE_STEP_DELAY = Delay.CONTROL
# One press always dabs once; the repeats are what the hold buys. Asserting a
# floor of 3 says the stroke kept painting as it moved, without pinning the exact
# count (it depends on the timer, not on us).
STROKE_MIN_DABS = 3

# A stroke reshapes a patch of ground metres across: zoomed in, with a brush this
# size, that is a large visible bulge -- far above the map's own shimmer.
MAP_STROKE_PIXELS = 20000

# The map's own frame-to-frame noise, orders of magnitude below a stroke.
MAP_SHIMMER = 200

ZOOM_CLICKS = 4


@scenario()
def pattern_preview(run_state: "RunState") -> None:
    """A selected Terrain/Add pattern is visibly projected under the cursor.

    The test does not paint. It arms Add with no pattern, then selects one and
    checks that the active brush gains its textured ground footprint. Zooming
    comes first so the wheel remains camera zoom, not brush resize.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    map_region = (0, 0, width - 500, height - 92)
    point = (width // 3, height // 2)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.FRAME)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.READY)
    run_state.wheel(*point, clicks=ZOOM_CLICKS * 2, up=True, delay=Delay.DIALOG)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=Delay.DIALOG)
    run_state.move(*point, delay=Delay.SETTLE)
    before = run_state.screenshot("armed-without-pattern")
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.DIALOG)
    run_state.move(*point, delay=Delay.FRAME)
    preview = run_state.screenshot("pattern-preview")
    run_state.assert_region_pixels(before, preview, map_region, min_changed=1_000)


@scenario()
def terrain_stationary_hold(run_state: "RunState") -> None:
    """Terrain Add keeps dabbing while held at one grounded cursor position.

    This is deliberately not a sweep: a moving pointer can mask a failed held
    update. A press waits through the inherited initial delay while remaining at
    the same point, then must produce several terrain commands in one stroke.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    point = (width // 3, height // 2)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.FRAME)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.READY)
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.DIALOG)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=Delay.SETTLE)
    run_state.wheel(*point, clicks=ZOOM_CLICKS, up=True, delay=Delay.DIALOG)

    before = run_state.assert_command_at_least("TerrainShapeModifyCommand", 0)
    run_state.press(*point)
    # No cursor movement: the delay merely gives the state manager updates in
    # which to repeat the same dab.
    run_state.move(*point, delay=Delay.READY)
    run_state.release(*point, delay=Delay.DIALOG)
    run_state.assert_command_at_least("TerrainShapeModifyCommand", before + 3)
    run_state.screenshot("stationary-stroke-complete")


@scenario()
def heightmap(run_state: "RunState") -> None:
    """Map -> Terrain: sweep each brush (Add, Set, Smooth) as a held stroke and
    undo/redo one.

    A stroke, not a click: the button goes down, the pointer sweeps across the
    map, and the button comes up at the far end -- so this covers the repeat
    timer and the streaming undo group, not merely "the command class exists".
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    map_region = (0, 0, width - 500, height - 92)

    def assert_map_pixels(before: Path, after: Path, **bounds: int) -> None:
        run_state.assert_region_pixels(before, after, map_region, **bounds)

    def stroke(x: int, y: int, dx: int, dy: int) -> None:
        """Hold and sweep. `move` between press and release is what the brush
        sees as motion; the dabs land along the way."""
        run_state.press(x, y)
        for i in range(1, STROKE_STEPS + 1):
            run_state.move(
                round(x + dx * i / STROKE_STEPS),
                round(y + dy * i / STROKE_STEPS),
                delay=STROKE_STEP_DELAY,
            )
        run_state.release(x + dx, y + dy)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.FRAME)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.READY)
    run_state.screenshot("terrain-open")
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.DIALOG)

    # The default camera sits far enough out that a 100-unit brush is a smudge a
    # few pixels across -- the stroke lands, but nothing in the shot says so. Zoom
    # in and paint with a brush the size of the hill it is meant to raise, so each
    # stroke is plainly visible in `stroke-*.png` and the diffs mean something.
    run_state.wheel(width // 3, height // 2, clicks=ZOOM_CLICKS, up=True, delay=Delay.DIALOG)
    _click_field(run_state, left, MAP["terrain_size"], "400")
    # Shape Modify applies a signed delta. Keep it representative: an enormous
    # strength makes the outcome depend on a few milliseconds of stroke timing
    # and can drive the terrain beyond what the engine handles robustly.
    _click_field(run_state, left, MAP["terrain_strength"], "10")
    _click_field(run_state, left, MAP["terrain_height"], "80")
    run_state.screenshot("brush-settings")

    # Each brush in turn, each as a held stroke over the same stretch of map, so
    # Set and Smooth act on the terrain Add just raised.
    for action, name, command in MAP_TERRAIN_BRUSHES:
        run_state.click(*panel_point(left, MAP_ACTIONS[action]), delay=Delay.DIALOG)
        run_state.move(*panel_point(left, PARK_PANEL), delay=Delay.SETTLE)
        before_shot = run_state.screenshot(f"before-{name}")
        before = run_state.assert_command_at_least(command, 0)

        stroke(width // 3, height // 2, 160, 90)
        run_state.move(*panel_point(left, PARK_PANEL), delay=Delay.DIALOG)
        after_shot = run_state.screenshot(f"stroke-{name}")

        run_state.assert_command_at_least(command, before + STROKE_MIN_DABS)
        if not any(f'shape_name: "{TERRAIN_PATTERN_PATH}"' in line for line in run_state.engine_log()):
            raise AssertionError("terrain brush did not receive the selected full VFS texture path")
        # The commands reaching the bridge is not the point: the terrain has to
        # actually change. A brush whose settings make it a no-op sends a full
        # stroke of commands and moves nothing.
        assert_map_pixels(before_shot, after_shot, min_changed=MAP_STROKE_PIXELS)

    # Undo/redo the last stroke. Each stroke is one group, so one ctrl+z takes
    # the whole smooth back off, however many dabs it was.
    #
    # AbstractState:KeyPress drops hotkeys while a mouse button still reads as
    # down, so let the stroke's release land before undoing.
    swept = run_state.screenshot("swept")
    run_state.key("ctrl+z", delay=Delay.READY)
    run_state.assert_any_command("UndoCommand")
    undone = run_state.screenshot("undone")
    assert_map_pixels(swept, undone, min_changed=100)
    run_state.key("ctrl+y", delay=Delay.READY)
    run_state.assert_any_command("RedoCommand")
    redone = run_state.screenshot("redone")
    assert_map_pixels(undone, redone, min_changed=100)
    # Redo puts the same terrain back. Not bit-for-bit: the map itself does not
    # render identically frame to frame, so allow its shimmer and nothing more.
    assert_map_pixels(swept, redone, max_changed=MAP_SHIMMER)


@scenario()
def texture_paint(run_state: "RunState") -> None:
    """Texture strokes -- Paint, Filter (blur) and Void -- on a zoomed-in map.

    Full-frame and zoomed close on purpose: the point is that the paint *lands
    on the map*, so every stroke is checked against the pixels as well as the
    command, and the extra zoom keeps the subtler Filter/Void results legible
    in the review images.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    map_region = (0, 0, width - 500, height - 92)
    paint_x, paint_y = width // 3, height // 2

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.SETTLE)
    run_state.wheel(paint_x, paint_y, clicks=ZOOM_CLICKS + 2, up=True, delay=Delay.DIALOG)

    # Texture Void erases diffuse alpha. The engine only renders that alpha as
    # transparent when Void ground is enabled; without this, a Void stroke can
    # emit its command while producing no visible result at all.
    run_state.click(*editor_point(left, "map", "settings"), delay=Delay.READY)
    run_state.click(*panel_point(left, MAP["void_ground"]), delay=Delay.DIALOG)
    run_state.assert_any_command("SetMapRenderingParamsCommand", voidGround=True)

    # A material has to be chosen before Paint will do anything, so the
    # saved-brush picker comes first. `tiles` is visibly orange and patterned;
    # cement is too pale to prove texture paint in a review image.
    run_state.click(*editor_point(left, "map", "texture"), delay=Delay.READY)
    run_state.click(*panel_point(left, MAP["saved_brush_add"]), delay=Delay.READY)
    run_state.screenshot_root("texture-material-picker")
    run_state.click(*dialog_point(run_state, DIALOG["asset_core_cell"]), delay=Delay.DIALOG)
    # A shaped pattern, not circle1: a stroke of circles is a row of dots, and a
    # rotation on a circle is a no-op.
    run_state.click(*panel_point(left, MAP["saved_brush_rect"]), delay=Delay.DIALOG)
    run_state.screenshot("texture-ready")

    # Paint, Filter (blur) and Void each paint. DNTS is skipped: it needs a splat
    # distribution texture the stock map has not got, and the button is disabled.
    for action, name, mode in MAP_TEXTURE_ACTIONS:
        run_state.click(*panel_point(left, MAP_ACTIONS[action]), delay=Delay.READY)
        before = run_state.screenshot(f"texture-before-{name}")
        _paint_stroke(run_state, left, paint_x, paint_y)
        after = run_state.screenshot(f"texture-{name}")
        run_state.assert_any_command("TerrainChangeTextureCommand", paintMode=mode, strength=1.0)
        run_state.assert_region_pixels(before, after, map_region, min_changed=MAP_STROKE_PIXELS)


@scenario()
def metal_paint(run_state: "RunState") -> None:
    """A metal stroke, checked in pixels under the metal view (F4) -- on the
    normal view metal is invisible and a "metal painted" shot proves nothing."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    map_region = (0, 0, width - 500, height - 92)
    paint_x, paint_y = width // 3, height // 2

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.SETTLE)
    run_state.wheel(paint_x, paint_y, clicks=ZOOM_CLICKS, up=True, delay=Delay.DIALOG)

    run_state.click(*editor_point(left, "map", "metal"), delay=Delay.READY)
    run_state.click(*panel_point(left, MAP["texture_pattern"]), delay=Delay.SETTLE)
    _click_field(run_state, left, MAP["metal_size"], "180")
    _click_field(run_state, left, MAP["metal_amount"], "3.25")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.READY)
    run_state.key("F4", delay=Delay.READY)
    before = run_state.screenshot("metal-view")
    _paint_stroke(run_state, left, paint_x, paint_y)
    after = run_state.screenshot("metal-painted")
    run_state.assert_any_command("TerrainMetalCommand", amount=3.25)
    run_state.assert_region_pixels(before, after, map_region, min_changed=MAP_STROKE_PIXELS)
    run_state.key("F4", delay=Delay.DIALOG)  # back to the normal view


@scenario()
def grass_paint(run_state: "RunState") -> None:
    """A grass stroke, checked in pixels at ground-level zoom -- engine grass
    only draws near the camera, so from the default distance a working brush
    looks like a no-op."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    map_region = (0, 0, width - 500, height - 92)
    paint_x, paint_y = width // 3, height // 2

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.SETTLE)
    run_state.wheel(paint_x, paint_y, clicks=ZOOM_CLICKS * 3, up=True, delay=Delay.DIALOG)

    run_state.click(*editor_point(left, "map", "grass"), delay=Delay.READY)
    run_state.click(*panel_point(left, MAP["texture_pattern"]), delay=Delay.SETTLE)
    _click_field(run_state, left, MAP["metal_size"], "180")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.READY)
    before = run_state.screenshot("grass-before")
    _paint_stroke(run_state, left, paint_x, paint_y)
    after = run_state.screenshot("grass-painted")
    run_state.assert_any_command("TerrainGrassCommand", amount=1.0)
    run_state.assert_region_pixels(before, after, map_region, min_changed=MAP_STROKE_PIXELS)


@scenario(crop="right-panel")
def map_editors(run_state: "RunState") -> None:
    """The Map editors' panels: every editor opens, its fields commit, and its
    dialogs (material, asset, shading-texture) work.

    Painting is the `texture_paint`/`metal_paint`/`grass_paint` scenarios' job;
    this case is about the panels.
    """
    run_state.focus()
    left = panel_left(run_state)

    def map_tab() -> None:
        run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.SETTLE)

    def editor_button(name: str, delay: Delay = Delay.READY) -> None:
        run_state.click(*editor_point(left, "map", name), delay=delay)

    map_tab()

    # 5. Map -> Terrain: the pattern grid, the numeric fields and the direction
    # drop-down. Rotation is set on `rect1`, not on a circle -- rotating a circle
    # is a no-op and says nothing about the field.
    editor_button("terrain")
    run_state.screenshot("terrain-open")
    run_state.click(*panel_point(left, MAP["texture_rect_pattern"]), delay=Delay.SETTLE)
    _click_field(run_state, left, MAP["terrain_size"], "140")
    _click_field(run_state, left, MAP["terrain_rotation"], "15")
    _click_field(run_state, left, MAP["terrain_strength"], "8.5")
    _click_field(run_state, left, MAP["terrain_height"], "25")
    run_state.click(*panel_point(left, MAP["texture_direction"]), delay=Delay.FRAME)
    run_state.click(*panel_point(left, dropdown_option(MAP["texture_direction"], 1)), delay=Delay.SETTLE)
    # Brush fields are brush state: no command is dispatched until a stroke
    # first uses the pattern (`texture_paint` covers that). The screenshot is the
    # commit evidence here.
    run_state.screenshot("terrain-fields")

    # 6. Map -> Texture: the editor's own fields, and the saved-brush dialog.
    editor_button("texture")
    run_state.screenshot("texture-open")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.READY)
    run_state.click(*panel_point(left, MAP["saved_brush_add"]), delay=Delay.READY)
    run_state.screenshot_root("texture-material-picker")
    run_state.click(*dialog_point(run_state, DIALOG["asset_core_cell"]), delay=Delay.DIALOG)
    run_state.screenshot("texture-saved-brushes")

    # Each action shows its own fields: Filter has a kernel, Void has none of the
    # blend fields. DNTS is disabled without a splat distribution texture.
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_filter"]), delay=Delay.READY)
    run_state.screenshot("texture-filter-fields")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_dnts"]), delay=Delay.READY)
    run_state.screenshot("texture-dnts-fields")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_void"]), delay=Delay.READY)
    run_state.screenshot("texture-void-fields")

    # 7. Map -> Metal, 8. Map -> Grass: their fields reach the brush.
    editor_button("metal")
    run_state.screenshot("metal-open")
    _click_field(run_state, left, MAP["metal_size"], "180")
    _click_field(run_state, left, MAP["metal_amount"], "3.25")
    run_state.screenshot("metal-fields")

    editor_button("grass")
    run_state.screenshot("grass-open")
    _click_field(run_state, left, MAP["metal_size"], "160")
    run_state.screenshot("grass-fields")

    # 9. Map -> Settings: boolean flags, splat scale/mult, shading toggles and
    # detail texture picker all dispatch the expected native commands.
    editor_button("settings")
    run_state.screenshot("settings-open")
    # One toggle and one splat field: every Settings field runs the same
    # commit path, and none of their effects are visible on this map --
    # `texture_paint` covers the observable void-ground case. Exercising all
    # eleven controls here would re-test the same plumbing ten more times.
    run_state.click(*panel_point(left, MAP["void_water"]), delay=Delay.DIALOG)
    run_state.assert_any_command("SetMapRenderingParamsCommand", voidWater=True)
    _click_field(run_state, left, MAP["splat_scale_1"], "2.5")
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        splatTexScales=list_first_is(2.5),
    )
    run_state.click(*panel_point(left, MAP["detail_texture"]), delay=Delay.READY)
    run_state.screenshot_root("detail-picker")
    # The asset picker opens on the *packs*, so the first cell is `core/` -- a
    # folder to go into -- and the file is picked on the screen after it.
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=Delay.READY)
    run_state.screenshot_root("detail-in-pack")
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=Delay.DIALOG)
    run_state.screenshot_root("detail-selected")
    run_state.click(*dialog_point(run_state, DIALOG["asset_ok"]), delay=Delay.READY)
    # The detail texture is a shading channel: the pick imports the image
    # (Lua's `AssignShadingTexture("detail", ...)`), it is not a rendering param.
    run_state.assert_any_command(
        "ImportShadingImageCommand",
        texType="detail",
        texturePath=string_contains("core/"),
    )
    # Shading entries are texture maps, not checkboxes. Open Specular, create
    # its engine texture, then open Emission and choose an existing texture.
    run_state.click(*panel_point(left, MAP["texture_specular"]), delay=Delay.READY)
    run_state.screenshot_root("settings-specular-dialog")
    run_state.click(*dialog_point(run_state, DIALOG["texture_new"]), delay=Delay.READY)
    run_state.screenshot_root("settings-specular-new-form")
    _click_dialog_field(run_state, DIALOG["texture_width"], "640")
    _click_dialog_field(run_state, DIALOG["texture_height"], "320")
    run_state.click(*dialog_point(run_state, DIALOG["texture_create"]), delay=Delay.READY)
    run_state.assert_any_command(
        "CreateShadingTextureCommand",
        name="specular",
        width=640,
        height=320,
    )
    run_state.click(*panel_point(left, MAP["texture_reflection"]), delay=Delay.READY)
    run_state.screenshot_root("settings-emission-dialog")
    run_state.click(*dialog_point(run_state, DIALOG["texture_existing"]), delay=Delay.FRAME)
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=Delay.READY)
    run_state.assert_any_command(
        "ImportShadingImageCommand",
        texType="emission",
    )


@scenario()
def settings_panel(run_state: "RunState") -> None:
    """Map -> Settings: enabling a shading texture must open a texture dialog."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "map", "settings"), delay=Delay.DIALOG)
    run_state.screenshot("settings-open")
    # Specular checkbox: disable, then re-enable -> must open a texture dialog.
    run_state.click(*panel_point(left, MAP["settings_map_size"]), delay=Delay.DIALOG)
    run_state.screenshot("specular-off")
    run_state.click(*panel_point(left, MAP["settings_map_size"]), delay=Delay.READY)
    run_state.screenshot_root("specular-on-root")


@scenario()
def editor_state_roundtrip(run_state: "RunState") -> None:
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
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.CONTROL)
    _click_field(run_state, left, MAP["terrain_size"], "333")
    _click_field(run_state, left, MAP["terrain_rotation"], "27")
    _click_field(run_state, left, MAP["terrain_strength"], "8.5")
    _click_field(run_state, left, MAP["terrain_height"], "44")
    run_state.click(*panel_point(left, MAP["texture_direction"]), delay=Delay.CONTROL)
    run_state.click(*panel_point(left, dropdown_option(MAP["texture_direction"], 2)), delay=Delay.CONTROL)

    # Create one texture preset. It captures the shared pattern/geometry plus
    # a real material, exactly the part that used to disappear on tab switches
    # and project reloads.
    run_state.click(*editor_point(left, "map", "texture"), delay=Delay.SETTLE)
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.CONTROL)
    _click_field(run_state, left, MAP["texture_scale"], "3.5")
    run_state.click(*panel_point(left, MAP["texture_specular_enabled"]), delay=Delay.CONTROL)
    run_state.click(*panel_point(left, MAP["saved_brush_add"]), delay=Delay.SETTLE)
    run_state.click(*dialog_point(run_state, DIALOG["asset_core_cell"]), delay=Delay.SETTLE)

    # Save As writes this state, then reloads into the project. No screenshot is
    # needed: the command payloads below are stronger evidence and keep this
    # regression test quick. The reload's own project/bootstrap commands are
    # expected; editor-state hydration must add nothing to that set.
    before_save = len(run_state.commands())
    run_state.click(*panel_point(left, TOOLBAR["save_as"]), delay=Delay.SETTLE)
    run_state.click(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.CONTROL)
    run_state.type_text("EditorState")
    run_state.key("Return", delay=Delay.CONTROL)
    run_state.click(*dialog_point(run_state, DIALOG["file_ok_name"]), delay=Delay.MAP_EXPORT)

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


@scenario()
def map_export(run_state: "RunState") -> None:
    """The whole map pipeline: save a project, sculpt and paint the map, then
    compile it to a Spring archive.

    Save As establishes a project (Export needs its path); a Terrain/Add sweep
    reshapes the ground across the whole map, a texture sweep paints it, Ctrl+S
    saves, and Export -> Spring archive runs the bundled compiler. Asserts the
    sculpt/paint/export commands and that the compiled `.sdz` lands on disk.
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
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.INPUT)
    run_state.type_text("ExportMap")
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_ok_name"]), delay=Delay.INPUT)
    run_state.wait_for_command("ReloadIntoProjectCommand")
    run_state.wait_for_log("finished loading and is now ingame", after=reload_log)

    # Terrain: pick a pattern, arm Add, a fat brush, one sweep across the map.
    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.FRAME)
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.CONTROL)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=Delay.CONTROL)
    _click_field(run_state, left, MAP["terrain_size"], "1200")
    _click_field(run_state, left, MAP["terrain_strength"], "1000")
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
    save_log = run_state.log_cursor()
    run_state.key("ctrl+s", delay=Delay.DIALOG)
    run_state.assert_command_at_least("SaveCommand", 1)
    run_state.wait_for_log("save editor state:", after=save_log)
    run_state.click_settled(*panel_point(left, TOOLBAR["export"]), delay=Delay.CONTROL)
    run_state.click_settled(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.INPUT)
    run_state.type_text("ExportMap")
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
    # `tiles` is orange while the base map is green, so this is a direct visual
    # assertion that the diffuse PNG made it through mapcompile and back in.
    map_region = (left // 2 - 260, height // 2 - 220, 520, 440)
    painted_before = run_state.count_color(edited, map_region, "#C87830", fuzz="18%")
    if painted_before < 5_000:
        raise AssertionError(f"texture paint was not visibly present before export ({painted_before} warm pixels)")
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
    painted_after = run_state.count_color(reopened, map_region, "#C87830", fuzz="18%")
    if painted_after < 5_000:
        raise AssertionError(f"exported map lost its painted diffuse texture ({painted_after} warm pixels)")
    if abs(painted_after - painted_before) > painted_before // 5:
        raise AssertionError(
            "exported diffuse texture moved within the map: "
            f"{painted_before} warm pixels before export, {painted_after} after reopening"
        )


@scenario()
def map_roundtrip(run_state: "RunState") -> None:
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
    run_state.click(*panel_point(left, TOOLBAR["save_as"]), delay=Delay.DIALOG)
    run_state.click(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.CONTROL)
    run_state.type_text("RoundTrip")
    run_state.key("Return", delay=Delay.CONTROL)
    run_state.click(*dialog_point(run_state, DIALOG["file_ok_name"]), delay=Delay.MAP_EXPORT)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.FRAME)
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=Delay.CONTROL)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=Delay.CONTROL)
    _click_field(run_state, left, MAP["terrain_size"], "1400")
    _click_field(run_state, left, MAP["terrain_strength"], "1000")
    _click_field(run_state, left, MAP["terrain_height"], "300")
    # Two sweeps at high strength for a pronounced, unmistakable relief.
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

    # The edited map as it looks in-editor, to compare the reopened export against.
    run_state.move(*panel_point(left, PARK_PANEL), delay=Delay.SETTLE)
    edited = run_state.screenshot("edited-map")

    # Give the map a unique scenario name so the export does not collide with the
    # default "Manual's Scenario". "AAA ..." sorts first, making it dropdown index 1.
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "misc", "info"), delay=Delay.SETTLE)
    _click_field(run_state, left, MISC["info_name"], "AAA RoundTrip")

    run_state.key("ctrl+s", delay=Delay.DIALOG)
    run_state.click(*panel_point(left, TOOLBAR["export"]), delay=Delay.FRAME)
    run_state.click(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.CONTROL)
    run_state.type_text("RoundTrip")
    run_state.key("Return", delay=Delay.CONTROL)
    run_state.click(*dialog_point(run_state, DIALOG["file_ok_export"]), delay=Delay.FRAME)
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
    run_state.click(*panel_point(left, TOOLBAR["new_project"]), delay=Delay.READY)
    # Name first, while the dialog still has its full layout.
    run_state.click(*dialog_point(run_state, DIALOG["new_project_name"]), delay=Delay.CONTROL)
    run_state.type_text("FromExport")
    run_state.key("Return", delay=Delay.CONTROL)
    # Open the map dropdown and pick the exported map. Its map name comes from the
    # scenario ("Manual's Scenario 1"), which sorts to option index 1 -- ahead of
    # the "RoundTrip 1.0" *project* entry, whose base map is flat.
    run_state.click(*dialog_point(run_state, DIALOG["new_project_map"]), delay=Delay.SETTLE)
    run_state.screenshot_root("roundtrip-map-dropdown")
    run_state.click(*dialog_point(run_state, dropdown_option(DIALOG["new_project_map"], 1)), delay=Delay.SETTLE)
    # Picking a non-blank map hides the Size row, so Create sits one row higher.
    run_state.screenshot_root("roundtrip-after-map")
    run_state.click(*dialog_point(run_state, DIALOG["new_project_create_nosize"]), delay=Delay.ARCHIVE)

    roundtrip = run_state.screenshot("roundtrip-loaded")
    # The compiled terrain came through: sharply different from the flat default
    # it started on...
    run_state.assert_region_pixels(original, roundtrip, map_region, min_changed=20_000)
    # ...and faithful to the pre-export edit -- reopening the export looks the same.
    run_state.assert_region_pixels(edited, roundtrip, map_region, max_changed=60_000)


def _click_field(run_state: "RunState", left: int, point: tuple[int, int], text: str) -> None:
    run_state.fill_text(*panel_point(left, point), text, click_delay=Delay.FRAME)


def _click_dialog_field(run_state: "RunState", point: tuple[int, int], text: str) -> None:
    run_state.fill_text(*dialog_point(run_state, point), text, click_delay=Delay.FRAME)


def _paint_stroke(run_state: "RunState", left: int, x: int, y: int, dx: int = 220, dy: int = 120) -> None:
    run_state.press(x, y)
    for i in range(1, STROKE_STEPS + 1):
        run_state.move(
            round(x + dx * i / STROKE_STEPS),
            round(y + dy * i / STROKE_STEPS),
            delay=STROKE_STEP_DELAY,
        )
    run_state.release(x + dx, y + dy)
    run_state.move(*panel_point(left, PARK_PANEL), delay=Delay.DIALOG)


def _sweep(run_state: "RunState", left: int, width: int, height: int) -> None:
    y = height // 2
    run_state.press(width // 3, y)
    run_state.move(left - 200, y, delay=Delay.SETTLE)
    run_state.release(left - 200, y)


def _wait_for_archive(run_state: "RunState", stem: str, timeout_s: Timeout = Timeout.ARCHIVE) -> Path | None:
    assert run_state.write_dir is not None
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        matches = list(run_state.write_dir.rglob(f"{stem}*.sdz"))
        if matches:
            return matches[0]
        pause(Delay.FRAME)
    return None
