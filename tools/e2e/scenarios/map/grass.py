"""Map -> Grass painting scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import (
    MAP_ACTIONS,
    TAB_X,
    TAB_Y,
    panel_left,
    panel_point,
    window_size,
)
from e2e.scenarios.helpers.registry import scenario

from .common import MAP_STROKE_PIXELS, TERRAIN_PATTERN_PATH, _paint_stroke

if TYPE_CHECKING:
    from e2e.driver.state import RunState


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
    zoom_map(run_state, factor=0.125, point=(paint_x, paint_y))

    grass = run_state.control.editor("grassEditor")
    grass.set("patternTexture", TERRAIN_PATTERN_PATH)
    grass.size = 180.0
    run_state.click(*panel_point(left, MAP_ACTIONS["texture_paint"]), delay=Delay.READY)
    before = run_state.screenshot("grass-before")
    _paint_stroke(run_state, left, paint_x, paint_y)
    after = run_state.screenshot("grass-painted")
    run_state.assert_any_command("TerrainGrassCommand", amount=1.0)
    run_state.assert_region_pixels(before, after, map_region, min_changed=MAP_STROKE_PIXELS)
