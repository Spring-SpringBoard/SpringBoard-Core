"""Map tab: Terrain, Texture, Metal, Grass, Settings."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import (
    ACTION_Y,
    EDITOR_BUTTON_Y,
    TAB_X,
    TAB_Y,
    dialog_left,
    editor_button_x,
    panel_left,
    window_size,
)
from scenarios.registry import scenario

if TYPE_CHECKING:
    from runner import E2ERun


# The brush actions, in the order they sit on the toolbar.
TERRAIN_BRUSHES = (
    (42, "add", "TerrainShapeModifyCommand"),
    (112, "set", "TerrainLevelCommand"),
    (188, "smooth", "TerrainSmoothCommand"),
)

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

# Terrain fields, by their row in the panel. A click that lands *between* rows
# focuses nothing, and the typing then opens the engine's chat console instead.
SIZE_Y = 604
ROTATION_Y = 646
STRENGTH_Y = 690
HEIGHT_Y = 732

# Metal and Grass have no pattern-shape section above their fields, so their rows
# sit lower than Terrain's. A click between rows focuses nothing and the value is
# typed into whatever still had focus -- silently, one field off.
METAL_SIZE_Y = 625
METAL_ROTATION_Y = 668
METAL_AMOUNT_Y = 711
ZOOM_CLICKS = 4


def click_field(run_state: E2ERun, left: int, y: int, text: str, x: int = 92) -> None:
    """Type into the field on row `y`. A click that lands between rows focuses
    nothing, and the text then goes to whatever had focus -- or to the engine's
    chat console."""
    run_state.click(left + x, y, delay=0.3)
    run_state.key("ctrl+a", delay=0.1)
    run_state.type_text(text)
    run_state.key("Return", delay=0.35)


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
    run_state.click(width - 610, height - 115, delay=0.3)

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
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.8)    # Terrain (order 0)
    run_state.screenshot("terrain-open")
    run_state.click(left + 42, 365, delay=0.5)                # Select circle1 pattern

    # The default camera sits far enough out that a 100-unit brush is a smudge a
    # few pixels across -- the stroke lands, but nothing in the shot says so. Zoom
    # in and paint with a brush the size of the hill it is meant to raise, so each
    # stroke is plainly visible in `stroke-*.png` and the diffs mean something.
    run_state.wheel(width // 3, height // 2, clicks=ZOOM_CLICKS, up=True, delay=0.5)
    click_field(run_state, left, SIZE_Y, "400")     # Size
    click_field(run_state, left, STRENGTH_Y, "8")   # Strength
    click_field(run_state, left, HEIGHT_Y, "80")    # Height, for the Set brush
    run_state.screenshot("brush-settings")

    # Each brush in turn, each as a held stroke over the same stretch of map, so
    # Set and Smooth act on the terrain Add just raised.
    for x, name, command in TERRAIN_BRUSHES:
        run_state.click(left + x, ACTION_Y, delay=0.5)
        run_state.move(left + 450, 1000, delay=0.4)           # Hide brush preview
        before_shot = run_state.screenshot(f"before-{name}")
        before = run_state.assert_command_at_least(command, 0)

        stroke(width // 3, height // 2, 160, 90)
        run_state.move(left + 450, 1000, delay=0.5)
        after_shot = run_state.screenshot(f"stroke-{name}")

        run_state.assert_command_at_least(command, before + STROKE_MIN_DABS)
        # The commands reaching the bridge is not the point: the terrain has to
        # actually change. A brush whose settings make it a no-op sends a full
        # stroke of commands and moves nothing.
        run_state.assert_screenshot_pixels(before_shot, after_shot, min_changed=MAP_STROKE_PIXELS)

    # Undo/redo the last stroke. Each stroke is one group, so one ctrl+z takes
    # the whole smooth back off, however many dabs it was.
    #
    # AbstractState:KeyPress drops hotkeys while a mouse button still reads as
    # down, so let the stroke's release land before undoing.
    swept = run_state.screenshot("swept")
    run_state.key("ctrl+z", delay=0.9)
    run_state.assert_any_command("UndoCommand")
    undone = run_state.screenshot("undone")
    run_state.assert_screenshot_pixels(swept, undone, min_changed=100)
    run_state.key("ctrl+y", delay=0.9)
    run_state.assert_any_command("RedoCommand")
    redone = run_state.screenshot("redone")
    run_state.assert_screenshot_pixels(undone, redone, min_changed=100)
    # Redo puts the same terrain back. Not bit-for-bit: the map itself does not
    # render identically frame to frame, so allow its shimmer and nothing more.
    run_state.assert_screenshot_pixels(swept, redone, max_changed=MAP_SHIMMER)


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
    run_state.click(width - 610, height - 115, delay=0.3)
    modal_left = dialog_left(run_state)
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
        run_state.move(left + 450, 1000, delay=0.6)   # park: hide the brush preview

    def editor_button(index: int, delay: float = 0.7) -> None:
        run_state.click(left + editor_button_x(index), EDITOR_BUTTON_Y, delay=delay)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.35)
    run_state.wheel(paint_x, paint_y, clicks=ZOOM_CLICKS, up=True, delay=0.6)

    # Texture. A material has to be chosen before Paint will do anything, so the
    # saved-brush picker comes first.
    editor_button(1)
    # Set the brush up *before* arming an action: the action buttons toggle, so
    # clicking Paint here and again in the loop below would turn it back off.
    run_state.click(left + 42, 335, delay=0.8)          # Saved brushes: the + cell
    run_state.screenshot_root("texture-material-picker")
    run_state.click(modal_left + 50, 280, delay=0.6)    # the first material
    # A shaped pattern, not circle1: a stroke of circles is a row of dots, and a
    # rotation on a circle is a no-op.
    run_state.click(left + 112, 748, delay=0.5)         # rect1
    run_state.screenshot("texture-ready")

    # Paint, Filter (blur) and Void each paint. DNTS is skipped: it needs a splat
    # distribution texture the stock map has not got, and the button is disabled.
    for x, name, mode in (
        (42, "paint", "paint"),
        (112, "filter", "blur"),
        (260, "void", "void"),
    ):
        run_state.click(left + x, ACTION_Y, delay=0.8)
        before = run_state.screenshot(f"texture-before-{name}")
        stroke()
        after = run_state.screenshot(f"texture-{name}")
        run_state.assert_any_command("TerrainChangeTextureCommand", paintMode=mode)
        run_state.assert_screenshot_pixels(before, after, min_changed=MAP_STROKE_PIXELS)

    # Metal, under the metal view (F4) -- otherwise the paint is invisible and the
    # shot shows nothing but grass.
    editor_button(2)
    run_state.click(left + 42, 380, delay=0.4)          # pattern
    click_field(run_state, left, METAL_SIZE_Y, "180")
    click_field(run_state, left, METAL_AMOUNT_Y, "3.25")
    run_state.click(left + 42, ACTION_Y, delay=0.8)
    run_state.key("F4", delay=0.8)
    before = run_state.screenshot("metal-view")
    stroke()
    after = run_state.screenshot("metal-painted")
    run_state.assert_any_command("TerrainMetalCommand", amount=3.25)
    run_state.assert_screenshot_pixels(before, after, min_changed=MAP_STROKE_PIXELS)
    run_state.key("F4", delay=0.6)                     # back to the normal view

    # Grass.
    editor_button(3)
    run_state.click(left + 42, 380, delay=0.4)
    click_field(run_state, left, METAL_SIZE_Y, "180")
    run_state.click(left + 42, ACTION_Y, delay=0.8)
    before = run_state.screenshot("grass-before")
    stroke()
    after = run_state.screenshot("grass-painted")
    run_state.assert_any_command("TerrainGrassCommand", amount=1.0)
    run_state.assert_screenshot_pixels(before, after, min_changed=MAP_STROKE_PIXELS)


@scenario(crop="right-panel")
def map_editors(run_state: E2ERun) -> None:
    """The Map editors' panels: every editor opens, its fields commit, and its
    dialogs (material, asset, shading-texture) work.

    Painting is `map_paint`'s job; this case is about the panels.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    run_state.click(width - 610, height - 115, delay=0.3)
    modal_left = dialog_left(run_state)

    def map_tab() -> None:
        run_state.click(left + TAB_X["map"], TAB_Y, delay=0.35)

    def editor_button(index: int, delay: float = 0.7) -> None:
        run_state.click(left + editor_button_x(index), EDITOR_BUTTON_Y, delay=delay)

    map_tab()

    # 5. Map -> Terrain: the pattern grid, the numeric fields and the direction
    # drop-down. Rotation is set on `rect1`, not on a circle -- rotating a circle
    # is a no-op and says nothing about the field.
    editor_button(0)
    run_state.screenshot("terrain-open")
    run_state.click(left + 112, 448, delay=0.4)  # rect1 pattern
    click_field(run_state, left, SIZE_Y, "140")
    click_field(run_state, left, ROTATION_Y, "15")
    click_field(run_state, left, STRENGTH_Y, "8.5")
    click_field(run_state, left, HEIGHT_Y, "25")
    run_state.click(left + 200, 783, delay=0.3)  # Direction
    run_state.key("Down", delay=0.35)            # Only Raise
    # Commit the drop-down. Left open, it swallows the next press.
    run_state.key("Return", delay=0.35)
    run_state.screenshot("terrain-fields")
    run_state.assert_any_command("SetHeightmapBrushCommand")

    # 6. Map -> Texture: the editor's own fields, and the saved-brush dialog.
    editor_button(1)
    run_state.screenshot("texture-open")
    run_state.click(left + 42, ACTION_Y, delay=0.8)   # Paint
    run_state.click(left + 42, 335, delay=0.8)        # Saved brushes: the + cell
    run_state.screenshot_root("texture-material-picker")
    run_state.click(modal_left + 50, 280, delay=0.6)  # the first material
    run_state.screenshot("texture-saved-brushes")

    # Each action shows its own fields: Filter has a kernel, Void has none of the
    # blend fields. DNTS is disabled without a splat distribution texture.
    run_state.click(left + 112, ACTION_Y, delay=0.8)
    run_state.screenshot("texture-filter-fields")
    run_state.click(left + 188, ACTION_Y, delay=0.8)
    run_state.screenshot("texture-dnts-fields")
    run_state.click(left + 260, ACTION_Y, delay=0.8)
    run_state.screenshot("texture-void-fields")

    # 7. Map -> Metal, 8. Map -> Grass: their fields reach the brush.
    editor_button(2)
    run_state.screenshot("metal-open")
    click_field(run_state, left, METAL_SIZE_Y, "180")
    click_field(run_state, left, METAL_AMOUNT_Y, "3.25")
    run_state.screenshot("metal-fields")

    editor_button(3)
    run_state.screenshot("grass-open")
    click_field(run_state, left, METAL_SIZE_Y, "160")
    run_state.screenshot("grass-fields")

    # 9. Map -> Settings: boolean flags, splat scale/mult, shading toggles and
    # detail texture picker all dispatch the expected native commands.
    editor_button(4)
    run_state.screenshot("settings-open")
    run_state.click(left + 98, 185, delay=0.45)   # Void water
    run_state.assert_any_command("SetMapRenderingParamsCommand", voidWater=True)
    run_state.click(left + 226, 185, delay=0.35)  # Void ground
    run_state.click(left + 142, 217, delay=0.35)   # DNTS diffuse alpha
    click_field(run_state, left, 282, "2.5")            # Scale 1
    click_field(run_state, left, 282, "2.75", x=260)    # Scale 2
    click_field(run_state, left, 327, "3.0")            # Scale 3
    click_field(run_state, left, 327, "3.25", x=260)    # Scale 4
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        splatTexScales=lambda v: isinstance(v, list) and v[0] == 2.5,
    )
    click_field(run_state, left, 370, "0.75")           # Mult 1
    click_field(run_state, left, 370, "0.8", x=260)     # Mult 2
    click_field(run_state, left, 416, "0.85")           # Mult 3
    click_field(run_state, left, 416, "0.9", x=260)     # Mult 4
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        splatTexMults=lambda v: isinstance(v, list) and v[0] == 0.75,
    )
    run_state.click(left + 70, 480, delay=0.8)    # Detail texture
    run_state.screenshot_root("detail-picker")
    # The asset picker opens on the *packs*, so the first cell is `core/` -- a
    # folder to go into -- and the file is picked on the screen after it.
    run_state.click(modal_left + 50, 335, delay=0.8)   # into the core pack
    run_state.screenshot_root("detail-in-pack")
    run_state.click(modal_left + 50, 335, delay=0.5)   # the first detail texture
    run_state.screenshot_root("detail-selected")
    run_state.click(modal_left + 343, 603, delay=0.8)  # OK
    # An asset field commits an *asset path* (`core/...`), which is what a project
    # stores -- not a VFS path.
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        detailTexture=lambda v: isinstance(v, str) and v.startswith("core/"),
    )
    # Shading entries are texture maps, not checkboxes. Open Specular, create
    # its engine texture, then open Emission and choose an existing texture.
    run_state.click(left + 140, 518, delay=0.7)
    run_state.screenshot("settings-specular-dialog")
    run_state.click(modal_left + 40, 270, delay=0.8)  # New texture
    run_state.assert_any_command(
        "SetMapShadingTextureEnabledCommand",
        name="specular",
        value=True,
    )
    run_state.click(left + 140, 562, delay=0.7)
    run_state.screenshot("settings-emission-dialog")
    run_state.click(modal_left + 110, 270, delay=0.3)  # Choose existing
    run_state.click(modal_left + 40, 335, delay=0.8)    # First existing texture
    run_state.assert_any_command(
        "ImportShadingImageCommand",
        texType="emission",
    )


@scenario(uis=("chili", "rmlui", "rust"), crop="right-panel")
def texture_panel(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    run_state.click(width - 610, height - 115, delay=0.3)
    # Map tab.
    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.2)
    run_state.screenshot("map-tab")
    # Texture editor is toolbox order 1 (second button).
    run_state.click(left + 110, EDITOR_BUTTON_Y, delay=0.5)
    run_state.screenshot("texture-open")
    # Paint mode reveals the saved-brushes ("mapMaterials") grid with its "+"
    # add item; clicking it must open the material picker with materials in it.
    run_state.click(left + 44, ACTION_Y, delay=0.5)
    run_state.screenshot("paint-mode")
    run_state.click(left + 40, 335, delay=0.8)
    run_state.screenshot_root("material-picker-root")
    modal_left = dialog_left(run_state)
    run_state.click(modal_left + 50, 280, delay=0.8)   # cement saved brush
    run_state.click(left + 42, 665, delay=0.6)         # circle1 pattern
    run_state.screenshot("texture-armed")
    run_state.drag(width // 3, height // 2, width // 3 + 120, height // 2 + 70, steps=8)
    run_state.assert_any_command("TerrainChangeTextureCommand", paintMode="paint")
    run_state.screenshot("texture-painted")

    # Texture setup must not poison the other map brush editors.
    for editor_index, command in (
        (0, "TerrainShapeModifyCommand"),
        (2, "TerrainMetalCommand"),
        (3, "TerrainGrassCommand"),
    ):
        run_state.click(left + editor_button_x(editor_index), EDITOR_BUTTON_Y, delay=0.7)
        run_state.click(left + 42, 365 if editor_index == 0 else 380, delay=0.5)
        run_state.click(left + 42, ACTION_Y, delay=0.5)
        y = height // 2 + editor_index * 30
        run_state.drag(width // 3, y, width // 3 + 100, y + 60, steps=6)
        run_state.assert_any_command(command)
    run_state.screenshot("map-brushes-after-texture")


@scenario(uis=("rmlui", "rust"))
def settings_panel(run_state: E2ERun) -> None:
    """Map -> Settings: enabling a shading texture must open a texture dialog."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.2)
    run_state.click(left + 326, EDITOR_BUTTON_Y, delay=0.6)   # Settings (order 5)
    run_state.screenshot("settings-open")
    # Specular checkbox: disable, then re-enable -> must open a texture dialog.
    run_state.click(left + 142, 525, delay=0.5)
    run_state.screenshot("specular-off")
    run_state.click(left + 142, 525, delay=0.9)
    run_state.screenshot_root("specular-on-root")


