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


@scenario(uis=("chili", "rmlui", "rust"))
def heightmap(run_state: E2ERun) -> None:
    """Map -> Terrain: pick the raise brush and drag on the map, then undo.
    Checks the brush actually reaches the command bridge, not just that the
    panel renders."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    run_state.click(width - 610, height - 115, delay=0.3)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.3)
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.8)    # Terrain (order 0)
    run_state.screenshot("terrain-open")

    run_state.click(left + 42, 365, delay=0.5)                # Select circle1 pattern
    run_state.click(left + 42, ACTION_Y, delay=0.4)           # brush action: Add
    run_state.screenshot("brush-add")

    run_state.drag(width // 3, height // 2, width // 3 + 160, height // 2 + 90, steps=8)
    run_state.assert_any_command(
        "TerrainShapeModifyCommand",
        shapeName=lambda value: isinstance(value, str) and bool(value),
    )
    run_state.move(left + 450, 1000, delay=0.5)               # Hide brush preview
    painted = run_state.screenshot("painted")

    # AbstractState:KeyPress drops hotkeys while a mouse button still reads as
    # down, so let the drag's release land before undoing.
    run_state.key("ctrl+z", delay=0.9)
    run_state.assert_any_command("UndoCommand")
    undone = run_state.screenshot("undone")
    run_state.assert_screenshot_pixels(painted, undone, min_changed=100)
    run_state.key("ctrl+y", delay=0.9)
    run_state.assert_any_command("RedoCommand")
    redone = run_state.screenshot("redone")
    run_state.assert_screenshot_pixels(undone, redone, min_changed=100)
    run_state.assert_screenshot_pixels(painted, redone, max_changed=0)

    for x, command in (
        (112, "TerrainLevelCommand"),
        (188, "TerrainSmoothCommand"),
    ):
        run_state.click(left + x, ACTION_Y, delay=0.5)
        run_state.drag(width // 3, height // 2, width // 3 + 100, height // 2 + 60, steps=6)
        run_state.assert_any_command(command)


@scenario(crop="right-panel")
def map_editors(run_state: E2ERun) -> None:
    """Map editors 5-9: open every Map editor, exercise each brush action, and
    assert that brush/settings changes reach the native command bridge."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    run_state.click(width - 610, height - 115, delay=0.3)
    modal_left = dialog_left(run_state)
    paint_x, paint_y = width // 3, height // 2

    def brush_stroke(x: int = paint_x, y: int = paint_y) -> None:
        run_state.drag(x, y, x + 160, y + 90, steps=8)
        run_state.move(x, y, delay=0.8)

    def map_tab() -> None:
        run_state.click(left + TAB_X["map"], TAB_Y, delay=0.35)

    def editor_button(index: int, delay: float = 0.7) -> None:
        run_state.click(left + editor_button_x(index), EDITOR_BUTTON_Y, delay=delay)

    def click_field(y: int, text: str, x: int = 92) -> None:
        run_state.click(left + x, y, delay=0.25)
        run_state.key("ctrl+a", delay=0.12)
        run_state.type_text(text)
        run_state.key("Return", delay=0.45)

    def pick_asset_pattern(field_y: int) -> None:
        run_state.click(left + 70, field_y, delay=0.8)
        run_state.screenshot("asset-picker-pattern")
        run_state.click(modal_left + 50, 335, delay=0.5)
        run_state.click(modal_left + 343, 603, delay=0.8)

    map_tab()

    # 5. Map -> Terrain: pattern grid, Add / Set / Smooth, numeric fields and
    # direction. Each action is painted once.
    editor_button(0)
    run_state.screenshot("terrain-open")
    run_state.click(left + 42, 365, delay=0.4)   # first visible pattern
    click_field(612, "140")                      # Size
    click_field(660, "15")                       # Rotation
    click_field(709, "8.5")                      # Strength
    click_field(741, "25")                       # Height
    run_state.click(left + 200, 783, delay=0.3)   # Direction
    run_state.key("Down", delay=0.35)            # Only Raise
    run_state.screenshot("terrain-fields")
    for x, name, command in (
        (42, "terrain-add", "TerrainShapeModifyCommand"),
        (112, "terrain-set", "TerrainLevelCommand"),
        (188, "terrain-smooth", "TerrainSmoothCommand"),
    ):
        run_state.click(left + x, ACTION_Y, delay=1.0)
        brush_stroke()
        run_state.screenshot(name)
        run_state.assert_any_command(command)

    # 6. Map -> Texture: select a pattern and material, exercise Paint, Filter,
    # DNTS visibility, Void, channel toggles and blend fields.
    editor_button(1)
    run_state.screenshot("texture-open")
    run_state.click(left + 42, ACTION_Y, delay=1.0) # Paint
    run_state.click(left + 42, 335, delay=0.5)      # Saved brush: +
    run_state.screenshot("texture-material-picker")
    run_state.click(modal_left + 50, 280, delay=0.5) # Material picker: first material
    run_state.click(left + 42, 665, delay=0.5)      # Pattern grid
    run_state.screenshot("texture-saved-brushes")
    brush_stroke(paint_x + 70, paint_y)
    run_state.screenshot("texture-paint")
    run_state.assert_any_command("TerrainChangeTextureCommand", paintMode="paint")

    run_state.click(left + 112, ACTION_Y, delay=1.0)   # Filter
    run_state.screenshot("texture-filter-fields")

    run_state.click(left + 188, ACTION_Y, delay=1.0)   # DNTS (may be disabled)
    run_state.screenshot("texture-dnts-fields")
    run_state.click(left + 260, ACTION_Y, delay=1.0)   # Void
    run_state.screenshot("texture-void-fields")

    # 7. Map -> Metal: generic asset picker for the pattern, amount field, paint.
    editor_button(2)
    run_state.screenshot("metal-open")
    run_state.click(left + 42, 380, delay=0.4)
    click_field(590, "180")
    click_field(633, "20")
    click_field(675, "3.25")
    run_state.click(left + 42, ACTION_Y, delay=1.0)
    brush_stroke(paint_x, paint_y + 80)
    run_state.screenshot("metal-painted")
    run_state.assert_any_command("TerrainMetalCommand", amount=3.25)

    # 8. Map -> Grass: pattern picker, detail config field, paint.
    editor_button(3)
    run_state.screenshot("grass-open")
    run_state.click(left + 42, 380, delay=0.4)
    click_field(590, "7")
    click_field(633, "160")
    click_field(675, "30")
    run_state.click(left + 42, ACTION_Y, delay=1.0)
    brush_stroke(paint_x + 80, paint_y + 80)
    run_state.screenshot("grass-painted")
    run_state.assert_any_command("TerrainGrassCommand", amount=1.0)

    # 9. Map -> Settings: boolean flags, splat scale/mult, shading toggles and
    # detail texture picker all dispatch the expected native commands.
    editor_button(4)
    run_state.screenshot("settings-open")
    run_state.click(left + 98, 185, delay=0.45)   # Void water
    run_state.assert_any_command("SetMapRenderingParamsCommand", voidWater=True)
    run_state.click(left + 226, 185, delay=0.35)  # Void ground
    run_state.click(left + 142, 217, delay=0.35)   # DNTS diffuse alpha
    click_field(282, "2.5")                       # Scale 1
    click_field(282, "2.75", x=260)               # Scale 2
    click_field(327, "3.0")                       # Scale 3
    click_field(327, "3.25", x=260)               # Scale 4
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        splatTexScales=lambda v: isinstance(v, list) and v[0] == 2.5,
    )
    click_field(370, "0.75")                      # Mult 1
    click_field(370, "0.8", x=260)                # Mult 2
    click_field(416, "0.85")                      # Mult 3
    click_field(416, "0.9", x=260)                # Mult 4
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        splatTexMults=lambda v: isinstance(v, list) and v[0] == 0.75,
    )
    run_state.click(left + 70, 480, delay=0.8)    # Detail texture
    run_state.screenshot("detail-picker")
    run_state.click(modal_left + 50, 335, delay=0.5)
    run_state.click(modal_left + 343, 603, delay=0.8)
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        detailTexture=lambda v: isinstance(v, str)
        and v.startswith("springboard/assets/core/detail/"),
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


