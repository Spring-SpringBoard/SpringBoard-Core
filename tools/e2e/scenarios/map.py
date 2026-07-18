"""Map tab: Terrain, Texture, Metal, Grass, Settings."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import (
    DIALOG,
    MAP,
    MAP_ACTIONS,
    MAP_TERRAIN_BRUSHES,
    MAP_TEXTURE_ACTIONS,
    PARK_PANEL,
    STATUS,
    TAB_X,
    TAB_Y,
    dialog_point,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)
from scenarios.registry import scenario

if TYPE_CHECKING:
    from runner import E2ERun


TERRAIN_PATTERN_PATH = "springboard/assets/core/brush_patterns/terrain/circle1.png"

# A stroke holds the button down and sweeps. The brush waits out an initial delay
# (0.3s) before a *held* button starts repeating, then dabs on a timer -- so a
# quick drag is one dab and proves nothing about holding. These numbers keep the
# button down for roughly a second, which is several dabs.
STROKE_STEPS = 8
STROKE_STEP_DELAY = 0.13
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


def click_field(run_state: E2ERun, left: int, point: tuple[int, int], text: str) -> None:
    """Type into the field on row `y`. A click that lands between rows focuses
    nothing, and the text then goes to whatever had focus -- or to the engine's
    chat console."""
    run_state.click(*panel_point(left, point), delay=0.3)
    run_state.key("ctrl+a", delay=0.1)
    run_state.type_text(text)
    run_state.key("Return", delay=0.35)


@scenario()
def pattern_preview(run_state: E2ERun) -> None:
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

    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.3)
    run_state.click(*editor_point(left, "map", "terrain"), delay=0.7)
    run_state.wheel(*point, clicks=ZOOM_CLICKS * 2, up=True, delay=0.6)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=0.45)
    run_state.move(*point, delay=0.4)
    before = run_state.screenshot("armed-without-pattern")
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=0.55)
    run_state.move(*point, delay=0.3)
    preview = run_state.screenshot("pattern-preview")
    run_state.assert_region_pixels(before, preview, map_region, min_changed=1_000)


@scenario()
def terrain_stationary_hold(run_state: E2ERun) -> None:
    """Terrain Add keeps dabbing while held at one grounded cursor position.

    This is deliberately not a sweep: a moving pointer can mask a failed held
    update. A press waits through the inherited initial delay while remaining at
    the same point, then must produce several terrain commands in one stroke.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    point = (width // 3, height // 2)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.3)
    run_state.click(*editor_point(left, "map", "terrain"), delay=0.7)
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=0.5)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=0.4)
    run_state.wheel(*point, clicks=ZOOM_CLICKS, up=True, delay=0.5)

    before = run_state.assert_command_at_least("TerrainShapeModifyCommand", 0)
    run_state.press(*point)
    # No cursor movement: the delay merely gives the state manager updates in
    # which to repeat the same dab.
    run_state.move(*point, delay=0.9)
    run_state.release(*point, delay=0.5)
    run_state.assert_command_at_least("TerrainShapeModifyCommand", before + 3)
    run_state.screenshot("stationary-stroke-complete")


@scenario(uis=("chili", "rmlui", "rust"))
def heightmap(run_state: E2ERun) -> None:
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
    run_state.click(width - STATUS["map_toggle_from_right"][0], height - STATUS["map_toggle_from_right"][1], delay=0.3)

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

    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.3)
    run_state.click(*editor_point(left, "map", "terrain"), delay=0.8)
    run_state.screenshot("terrain-open")
    run_state.click(*panel_point(left, MAP["terrain_pattern"]), delay=0.5)

    # The default camera sits far enough out that a 100-unit brush is a smudge a
    # few pixels across -- the stroke lands, but nothing in the shot says so. Zoom
    # in and paint with a brush the size of the hill it is meant to raise, so each
    # stroke is plainly visible in `stroke-*.png` and the diffs mean something.
    run_state.wheel(width // 3, height // 2, clicks=ZOOM_CLICKS, up=True, delay=0.5)
    click_field(run_state, left, MAP["terrain_size"], "400")
    click_field(run_state, left, MAP["terrain_strength"], "8")
    click_field(run_state, left, MAP["terrain_height"], "80")
    run_state.screenshot("brush-settings")

    # Each brush in turn, each as a held stroke over the same stretch of map, so
    # Set and Smooth act on the terrain Add just raised.
    for action, name, command in MAP_TERRAIN_BRUSHES:
        run_state.click(*panel_point(left, MAP_ACTIONS[action]), delay=0.5)
        run_state.move(*panel_point(left, PARK_PANEL), delay=0.4)
        before_shot = run_state.screenshot(f"before-{name}")
        before = run_state.assert_command_at_least(command, 0)

        stroke(width // 3, height // 2, 160, 90)
        run_state.move(*panel_point(left, PARK_PANEL), delay=0.5)
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
    run_state.key("ctrl+z", delay=0.9)
    run_state.assert_any_command("UndoCommand")
    undone = run_state.screenshot("undone")
    assert_map_pixels(swept, undone, min_changed=100)
    run_state.key("ctrl+y", delay=0.9)
    run_state.assert_any_command("RedoCommand")
    redone = run_state.screenshot("redone")
    assert_map_pixels(undone, redone, min_changed=100)
    # Redo puts the same terrain back. Not bit-for-bit: the map itself does not
    # render identically frame to frame, so allow its shimmer and nothing more.
    assert_map_pixels(swept, redone, max_changed=MAP_SHIMMER)


@scenario()
def map_paint(run_state: E2ERun) -> None:
    """The painting brushes -- Texture (Paint, Filter, Void), Metal and Grass --
    each as a held stroke on a zoomed-in map.

    Full-frame and zoomed in on purpose: the point is that the paint *lands on
    the map*, so every stroke is checked against the pixels as well as the
    command. Metal is painted with the metal view on (F4), because metal is
    invisible on the normal one -- a "metal painted" shot of plain grass proves
    nothing.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    map_region = (0, 0, width - 500, height - 92)

    def assert_map_pixels(before: Path, after: Path, **bounds: int) -> None:
        run_state.assert_region_pixels(before, after, map_region, **bounds)
    run_state.click(width - STATUS["map_toggle_from_right"][0], height - STATUS["map_toggle_from_right"][1], delay=0.3)
    paint_x, paint_y = width // 3, height // 2

    def stroke(dx: int = 220, dy: int = 120) -> None:
        """Hold and sweep, so the brush paints a line rather than one dab."""
        run_state.press(paint_x, paint_y)
        for i in range(1, STROKE_STEPS + 1):
            run_state.move(
                round(paint_x + dx * i / STROKE_STEPS),
                round(paint_y + dy * i / STROKE_STEPS),
                delay=STROKE_STEP_DELAY,
            )
        run_state.release(paint_x + dx, paint_y + dy)
        run_state.move(*panel_point(left, PARK_PANEL), delay=0.6)

    def editor_button(name: str, delay: float = 0.7) -> None:
        run_state.click(*editor_point(left, "map", name), delay=delay)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.35)
    run_state.wheel(paint_x, paint_y, clicks=ZOOM_CLICKS, up=True, delay=0.6)

    # Texture Void erases diffuse alpha. The engine only renders that alpha as
    # transparent when Void ground is enabled; without this, a Void stroke can
    # emit its command while producing no visible result at all.
    editor_button("settings")
    # Map Settings puts all texture sources first, then the visibility toggles.
    # Keep this coordinate tied to the actual full-width switch rather than the
    # old two-column layout (where y=185 now hits Detail texture).
    run_state.click(*panel_point(left, MAP["void_ground"]), delay=0.45)
    run_state.assert_any_command("SetMapRenderingParamsCommand", voidGround=True)

    # Texture. A material has to be chosen before Paint will do anything, so the
    # saved-brush picker comes first.
    editor_button("texture")
    # Set the brush up before arming Paint; pattern/material configuration is
    # independent from choosing the action.
    run_state.click(*panel_point(left, MAP["saved_brush_add"]), delay=0.8)
    run_state.screenshot_root("texture-material-picker")
    # `tiles` is visibly orange and patterned. Cement is too pale to prove
    # texture paint in a review image even when the command landed.
    run_state.click(*dialog_point(run_state, DIALOG["asset_core_cell"]), delay=0.6)
    # A shaped pattern, not circle1: a stroke of circles is a row of dots, and a
    # rotation on a circle is a no-op.
    run_state.click(*panel_point(left, MAP["saved_brush_rect"]), delay=0.5)
    run_state.screenshot("texture-ready")

    # Paint, Filter (blur) and Void each paint. DNTS is skipped: it needs a splat
    # distribution texture the stock map has not got, and the button is disabled.
    for action, name, mode in MAP_TEXTURE_ACTIONS:
        run_state.click(*panel_point(left, MAP_ACTIONS[action]), delay=0.8)
        before = run_state.screenshot(f"texture-before-{name}")
        stroke()
        after = run_state.screenshot(f"texture-{name}")
        run_state.assert_any_command("TerrainChangeTextureCommand", paintMode=mode)
        assert_map_pixels(before, after, min_changed=MAP_STROKE_PIXELS)

    # Metal, under the metal view (F4) -- otherwise the paint is invisible and the
    # shot shows nothing but grass.
    editor_button("metal")
    run_state.click(*panel_point(left, MAP["texture_pattern"]), delay=0.4)
    click_field(run_state, left, MAP["metal_size"], "180")
    click_field(run_state, left, MAP["metal_amount"], "3.25")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=0.8)
    run_state.key("F4", delay=0.8)
    before = run_state.screenshot("metal-view")
    stroke()
    after = run_state.screenshot("metal-painted")
    run_state.assert_any_command("TerrainMetalCommand", amount=3.25)
    assert_map_pixels(before, after, min_changed=MAP_STROKE_PIXELS)
    run_state.key("F4", delay=0.6)                     # back to the normal view

    # Grass. The deterministic stock map used by this scenario has no grass
    # render layer, so its density-map update is not observable in pixels even
    # with GrassDetail enabled. The bridge command and its amount are therefore
    # the meaningful assertion here; terrain, texture (including Void), and
    # metal above all retain their visible-map assertions.
    editor_button("grass")
    run_state.click(*panel_point(left, MAP["texture_pattern"]), delay=0.4)
    click_field(run_state, left, MAP["metal_size"], "180")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=0.8)
    before = run_state.screenshot("grass-before")
    stroke()
    after = run_state.screenshot("grass-painted")
    run_state.assert_any_command("TerrainGrassCommand", amount=1.0)


@scenario(crop="right-panel")
def map_editors(run_state: E2ERun) -> None:
    """The Map editors' panels: every editor opens, its fields commit, and its
    dialogs (material, asset, shading-texture) work.

    Painting is `map_paint`'s job; this case is about the panels.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    run_state.click(width - STATUS["map_toggle_from_right"][0], height - STATUS["map_toggle_from_right"][1], delay=0.3)

    def map_tab() -> None:
        run_state.click(left + TAB_X["map"], TAB_Y, delay=0.35)

    def editor_button(name: str, delay: float = 0.7) -> None:
        run_state.click(*editor_point(left, "map", name), delay=delay)

    map_tab()

    # 5. Map -> Terrain: the pattern grid, the numeric fields and the direction
    # drop-down. Rotation is set on `rect1`, not on a circle -- rotating a circle
    # is a no-op and says nothing about the field.
    editor_button("terrain")
    run_state.screenshot("terrain-open")
    run_state.click(*panel_point(left, MAP["texture_rect_pattern"]), delay=0.4)
    click_field(run_state, left, MAP["terrain_size"], "140")
    click_field(run_state, left, MAP["terrain_rotation"], "15")
    click_field(run_state, left, MAP["terrain_strength"], "8.5")
    click_field(run_state, left, MAP["terrain_height"], "25")
    run_state.click(*panel_point(left, MAP["texture_direction"]), delay=0.3)
    run_state.key("Down", delay=0.35)            # Only Raise
    # Commit the drop-down. Left open, it swallows the next press.
    run_state.key("Return", delay=0.35)
    run_state.screenshot("terrain-fields")
    run_state.assert_any_command("SetHeightmapBrushCommand")

    # 6. Map -> Texture: the editor's own fields, and the saved-brush dialog.
    editor_button("texture")
    run_state.screenshot("texture-open")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=0.8)
    run_state.click(*panel_point(left, MAP["saved_brush_add"]), delay=0.8)
    run_state.screenshot_root("texture-material-picker")
    run_state.click(*dialog_point(run_state, DIALOG["asset_core_cell"]), delay=0.6)
    run_state.screenshot("texture-saved-brushes")

    # Each action shows its own fields: Filter has a kernel, Void has none of the
    # blend fields. DNTS is disabled without a splat distribution texture.
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_filter"]), delay=0.8)
    run_state.screenshot("texture-filter-fields")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_dnts"]), delay=0.8)
    run_state.screenshot("texture-dnts-fields")
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_void"]), delay=0.8)
    run_state.screenshot("texture-void-fields")

    # 7. Map -> Metal, 8. Map -> Grass: their fields reach the brush.
    editor_button("metal")
    run_state.screenshot("metal-open")
    click_field(run_state, left, MAP["metal_size"], "180")
    click_field(run_state, left, MAP["metal_amount"], "3.25")
    run_state.screenshot("metal-fields")

    editor_button("grass")
    run_state.screenshot("grass-open")
    click_field(run_state, left, MAP["metal_size"], "160")
    run_state.screenshot("grass-fields")

    # 9. Map -> Settings: boolean flags, splat scale/mult, shading toggles and
    # detail texture picker all dispatch the expected native commands.
    editor_button("settings")
    run_state.screenshot("settings-open")
    # The three visibility controls are stacked after the ten map-texture
    # pickers.  Their whole rows are buttons, so centre-click each switch.
    run_state.click(*panel_point(left, MAP["void_water"]), delay=0.45)
    run_state.assert_any_command("SetMapRenderingParamsCommand", voidWater=True)
    run_state.click(*panel_point(left, MAP["void_ground"]), delay=0.35)
    run_state.click(*panel_point(left, MAP["dnts_diffuse_alpha"]), delay=0.35)
    click_field(run_state, left, MAP["splat_scale_1"], "2.5")
    click_field(run_state, left, MAP["splat_scale_2"], "2.75")
    click_field(run_state, left, MAP["splat_scale_3"], "3.0")
    click_field(run_state, left, MAP["splat_scale_4"], "3.25")
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        splatTexScales=lambda v: isinstance(v, list) and v[0] == 2.5,
    )
    click_field(run_state, left, MAP["splat_mult_1"], "0.75")
    click_field(run_state, left, MAP["splat_mult_2"], "0.8")
    click_field(run_state, left, MAP["splat_mult_3"], "0.85")
    click_field(run_state, left, MAP["splat_mult_4"], "0.9")
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        splatTexMults=lambda v: isinstance(v, list) and v[0] == 0.75,
    )
    run_state.click(*panel_point(left, MAP["detail_texture"]), delay=0.8)
    run_state.screenshot_root("detail-picker")
    # The asset picker opens on the *packs*, so the first cell is `core/` -- a
    # folder to go into -- and the file is picked on the screen after it.
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=0.8)
    run_state.screenshot_root("detail-in-pack")
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=0.5)
    run_state.screenshot_root("detail-selected")
    run_state.click(*dialog_point(run_state, DIALOG["asset_ok"]), delay=0.8)
    # An asset field commits an *asset path* (`core/...`), which is what a project
    # stores -- not a VFS path.
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        detailTexture=lambda v: isinstance(v, str) and v.startswith("core/"),
    )
    # Shading entries are texture maps, not checkboxes. Open Specular, create
    # its engine texture, then open Emission and choose an existing texture.
    run_state.click(*panel_point(left, MAP["texture_specular"]), delay=0.7)
    run_state.screenshot("settings-specular-dialog")
    run_state.click(*dialog_point(run_state, DIALOG["texture_new"]), delay=0.8)
    run_state.assert_any_command(
        "SetMapShadingTextureEnabledCommand",
        name="specular",
        value=True,
    )
    run_state.click(*panel_point(left, MAP["texture_reflection"]), delay=0.7)
    run_state.screenshot("settings-emission-dialog")
    run_state.click(*dialog_point(run_state, DIALOG["texture_existing"]), delay=0.3)
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=0.8)
    run_state.assert_any_command(
        "ImportShadingImageCommand",
        texType="emission",
    )


@scenario(uis=("chili", "rmlui", "rust"), crop="right-panel")
def texture_panel(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    run_state.click(width - STATUS["map_toggle_from_right"][0], height - STATUS["map_toggle_from_right"][1], delay=0.3)
    # Map tab.
    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.2)
    run_state.screenshot("map-tab")
    # Texture editor is toolbox order 1 (second button).
    run_state.click(*editor_point(left, "map", "texture"), delay=0.5)
    run_state.screenshot("texture-open")
    # Paint mode reveals the saved-brushes ("mapMaterials") grid with its "+"
    # add item; clicking it must open the material picker with materials in it.
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=0.5)
    run_state.screenshot("paint-mode")
    run_state.click(*panel_point(left, MAP["saved_brush_add"]), delay=0.8)
    run_state.screenshot_root("material-picker-root")
    run_state.click(*dialog_point(run_state, DIALOG["asset_core_cell"]), delay=0.8)
    run_state.click(*panel_point(left, MAP["saved_brush_pattern"]), delay=0.6)
    run_state.screenshot("texture-armed")
    run_state.drag(width // 3, height // 2, width // 3 + 120, height // 2 + 70, steps=8)
    run_state.assert_any_command("TerrainChangeTextureCommand", paintMode="paint")
    run_state.screenshot("texture-painted")

    # Texture setup must not poison the other map brush editors.
    for index, (editor_name, pattern, command) in enumerate((
        ("terrain", "terrain_pattern", "TerrainShapeModifyCommand"),
        ("metal", "texture_pattern", "TerrainMetalCommand"),
        ("grass", "texture_pattern", "TerrainGrassCommand"),
    )):
        run_state.click(*editor_point(left, "map", editor_name), delay=0.7)
        run_state.click(*panel_point(left, MAP[pattern]), delay=0.5)
        run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=0.5)
        y = height // 2 + index * 30
        run_state.drag(width // 3, y, width // 3 + 100, y + 60, steps=6)
        run_state.assert_any_command(command)
    run_state.screenshot("map-brushes-after-texture")


@scenario(uis=("rmlui", "rust"))
def settings_panel(run_state: E2ERun) -> None:
    """Map -> Settings: enabling a shading texture must open a texture dialog."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.2)
    run_state.click(*editor_point(left, "map", "settings"), delay=0.6)
    run_state.screenshot("settings-open")
    # Specular checkbox: disable, then re-enable -> must open a texture dialog.
    run_state.click(*panel_point(left, MAP["settings_map_size"]), delay=0.5)
    run_state.screenshot("specular-off")
    run_state.click(*panel_point(left, MAP["settings_map_size"]), delay=0.9)
    run_state.screenshot_root("specular-on-root")
