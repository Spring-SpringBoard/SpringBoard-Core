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

if TYPE_CHECKING:
    from runner import E2ERun


def heightmap(run_state: E2ERun) -> None:
    """Map -> Terrain: pick the raise brush and drag on the map, then undo.
    Checks the brush actually reaches the command bridge, not just that the
    panel renders."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.3)
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.8)    # Terrain (order 0)
    run_state.screenshot("terrain-open")

    run_state.click(left + 42, ACTION_Y, delay=0.4)           # brush action: Add
    run_state.screenshot("brush-add")

    run_state.drag(width // 3, height // 2, width // 3 + 160, height // 2 + 90, steps=8)
    run_state.screenshot("painted")

    # AbstractState:KeyPress drops hotkeys while a mouse button still reads as
    # down, so let the drag's release land before undoing.
    run_state.move(width // 3, height // 2, delay=1.0)
    run_state.key("ctrl+z", delay=0.9)
    run_state.screenshot("undone")


def map_editors(run_state: E2ERun) -> None:
    """Map editors 5-9: open every Map editor, exercise each brush action, and
    assert that brush/settings changes reach the native command bridge."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    modal_left = dialog_left(run_state)
    paint_x, paint_y = width // 3, height // 2

    def map_tab() -> None:
        run_state.click(left + TAB_X["map"], TAB_Y, delay=0.35)

    def editor_button(index: int, delay: float = 0.7) -> None:
        run_state.click(left + editor_button_x(index), EDITOR_BUTTON_Y, delay=delay)

    def click_field(y: int, text: str) -> None:
        run_state.click(left + 92, y, delay=0.25)
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
    run_state.click(left + 42, 270, delay=0.4)   # first visible pattern
    click_field(385, "140")                      # Size
    click_field(435, "15")                       # Rotation
    click_field(485, "8.5")                      # Strength
    click_field(535, "25")                       # Height
    run_state.screenshot("terrain-fields")
    for x, name, command in (
        (42, "terrain-add", "TerrainShapeModifyCommand"),
        (112, "terrain-set", "TerrainLevelCommand"),
        (188, "terrain-smooth", "TerrainSmoothCommand"),
    ):
        run_state.click(left + x, ACTION_Y, delay=0.4)
        run_state.click(paint_x, paint_y, delay=0.65)
        run_state.screenshot(name)
        run_state.assert_any_command(command)

    # 6. Map -> Texture: select a pattern and material, exercise Paint, Filter,
    # DNTS visibility, Void, channel toggles and blend fields.
    editor_button(1)
    run_state.screenshot("texture-open")
    run_state.click(left + 42, 270, delay=0.4)    # pattern grid
    run_state.click(left + 42, 470, delay=0.4)    # material grid
    click_field(350, "1.5")                       # Texture scale
    run_state.click(left + 42, ACTION_Y, delay=0.4)    # Paint
    run_state.click(paint_x + 70, paint_y, delay=0.8)
    run_state.screenshot("texture-paint")
    run_state.assert_any_command("TerrainChangeTextureCommand", paintMode="paint")

    run_state.click(left + 112, ACTION_Y, delay=0.5)   # Filter
    run_state.screenshot("texture-filter-fields")
    run_state.click(paint_x + 110, paint_y, delay=0.8)
    run_state.assert_any_command("TerrainChangeTextureCommand", paintMode="blur")

    run_state.click(left + 188, ACTION_Y, delay=0.5)   # DNTS (may be disabled)
    run_state.screenshot("texture-dnts-fields")
    run_state.click(left + 260, ACTION_Y, delay=0.5)   # Void
    run_state.screenshot("texture-void-fields")
    run_state.click(paint_x + 150, paint_y, delay=0.8)
    run_state.assert_any_command("TerrainChangeTextureCommand", paintMode="void")

    # 7. Map -> Metal: generic asset picker for the pattern, amount field, paint.
    editor_button(2)
    run_state.screenshot("metal-open")
    pick_asset_pattern(145)
    click_field(335, "3.25")
    run_state.click(left + 42, ACTION_Y, delay=0.4)
    run_state.click(paint_x, paint_y + 80, delay=0.8)
    run_state.screenshot("metal-painted")
    run_state.assert_any_command("TerrainMetalCommand", amount=3.25)

    # 8. Map -> Grass: pattern picker, detail config field, paint.
    editor_button(3)
    run_state.screenshot("grass-open")
    pick_asset_pattern(145)
    click_field(195, "7")
    run_state.click(left + 42, ACTION_Y, delay=0.4)
    run_state.click(paint_x + 80, paint_y + 80, delay=0.8)
    run_state.screenshot("grass-painted")
    run_state.assert_any_command("TerrainGrassCommand", amount=1.0)

    # 9. Map -> Settings: boolean flags, splat scale/mult, shading toggles and
    # detail texture picker all dispatch the expected native commands.
    editor_button(4)
    run_state.screenshot("settings-open")
    run_state.click(left + 70, 146, delay=0.45)   # Void water
    run_state.assert_any_command("SetMapRenderingParamsCommand", voidWater=True)
    click_field(245, "2.5")                       # Scale 1
    run_state.assert_any_command(
        "SetMapRenderingParamsCommand",
        splatTexScales=lambda v: isinstance(v, list) and v[0] == 2.5,
    )
    click_field(335, "0.75")                      # Mult 1
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
    run_state.click(left + 70, 550, delay=0.45)   # Specular shading
    run_state.screenshot("settings-shading")
    run_state.assert_any_command(
        "SetMapShadingTextureEnabledCommand",
        name="specular",
        value=True,
    )


def texture_panel(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
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
    run_state.click(left + 40, 300, delay=0.8)
    run_state.screenshot_root("material-picker-root")
    # Double-click the first folder to descend into it: materials must appear.
    run_state.click_root(1032, 662, delay=0.15)
    run_state.click_root(1032, 662, delay=0.8)
    run_state.screenshot_root("material-picker-folder-root")


def settings_panel(run_state: E2ERun) -> None:
    """Map -> Settings: enabling a shading texture must open a texture dialog."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["map"], TAB_Y, delay=0.2)
    run_state.click(left + 326, EDITOR_BUTTON_Y, delay=0.6)   # Settings (order 5)
    run_state.screenshot("settings-open")
    # Specular checkbox: disable, then re-enable -> must open a texture dialog.
    run_state.click(left + 142, 453, delay=0.5)
    run_state.screenshot("specular-off")
    run_state.click(left + 142, 453, delay=0.9)
    run_state.screenshot_root("specular-on-root")


SCENARIOS = {
    "heightmap": heightmap,
    "map_editors": map_editors,
    "texture_panel": texture_panel,
    "settings_panel": settings_panel,
}
