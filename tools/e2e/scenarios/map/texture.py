"""Map -> Texture painting scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import (
    DIALOG,
    MAP,
    MAP_ACTIONS,
    MAP_TEXTURE_ACTIONS,
    TAB_X,
    TAB_Y,
    dialog_point,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)
from e2e.scenarios.helpers.registry import scenario

from .common import MAP_STROKE_PIXELS, _paint_stroke

if TYPE_CHECKING:
    from e2e.driver.state import RunState


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
    zoom_map(run_state, factor=0.3, point=(paint_x, paint_y))

    # Texture Void erases diffuse alpha. The engine only renders that alpha as
    # transparent when Void ground is enabled; without this, a Void stroke can
    # emit its command while producing no visible result at all.
    settings = run_state.control.editor("terrainSettingsEditor")
    settings.voidGround = True
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
