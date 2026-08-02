"""Map -> Metal painting scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import (
    MAP,
    MAP_ACTIONS,
    TAB_X,
    TAB_Y,
    panel_left,
    panel_point,
    window_size,
)
from e2e.scenarios.helpers.registry import scenario

from .common import MAP_STROKE_PIXELS, _paint_stroke

if TYPE_CHECKING:
    from e2e.driver.state import RunState


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
    zoom_map(run_state, factor=0.5, point=(paint_x, paint_y))

    metal = run_state.control.editor("metalEditor")
    run_state.click(*panel_point(left, MAP["texture_pattern"]), delay=Delay.SETTLE)
    metal.size = 180.0
    metal.amount = 3.25
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.READY)
    metal_view = False
    try:
        run_state.key("F4", delay=Delay.READY)
        metal_view = True
        before = run_state.screenshot("metal-view")
        _paint_stroke(run_state, left, paint_x, paint_y)
        after = run_state.screenshot("metal-painted")
        run_state.assert_any_command("TerrainMetalCommand", amount=3.25)
        run_state.assert_region_pixels(before, after, map_region, min_changed=MAP_STROKE_PIXELS)
    finally:
        if metal_view:
            run_state.key("F4", delay=Delay.DIALOG)  # back to the normal view
