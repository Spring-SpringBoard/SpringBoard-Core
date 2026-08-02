"""Objects -> world and feature-grid tooltip scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import OBJECTS, panel_point, window_size
from e2e.scenarios.helpers.objects import arm_tree as _arm_tree
from e2e.scenarios.helpers.objects import open_object_editor as _open
from e2e.scenarios.helpers.registry import scenario

from .common import MAP_TOLERANCE, TOOLTIP_COLOR, _tip_box

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario()
def cursortip(run_state: "RunState") -> None:
    """Hovering a feature shows a useful tooltip next to the cursor.

    This is the native replacement for the engine's useless "No tooltip
    defined" overlay: it describes the actual unit or feature under the cursor.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    zoom_map(run_state, point=(spot_x, spot_y))
    run_state.click(spot_x, spot_y, delay=Delay.DIALOG)  # place it
    run_state.key("Escape", delay=Delay.FRAME)

    # Empty ground has no tip. `park=False` throughout -- the tip is drawn at
    # the cursor, so parking it out of shot would take the subject with it.
    run_state.move(spot_x + 320, spot_y - 260, delay=Delay.DIALOG)
    empty = run_state.golden("no-tooltip", crop=None, tolerance=MAP_TOLERANCE, park=False)
    if run_state.count_color(empty, _tip_box(spot_x + 320, spot_y - 260), TOOLTIP_COLOR):
        raise AssertionError("a tooltip over empty ground")

    # Hover the point the tree was placed on. The native pick projects the object's
    # *drawPos* -- a tree's base, not its crown -- and matches within 16px of the
    # cursor, so hovering the foliage up-left of it finds nothing.
    run_state.move(spot_x, spot_y, delay=Delay.READY)
    hovered = run_state.golden("hover-tooltip", crop=None, tolerance=MAP_TOLERANCE, park=False)
    tip = run_state.count_color(hovered, _tip_box(spot_x, spot_y), TOOLTIP_COLOR)
    if tip < 500:
        raise AssertionError(f"hovering the feature showed no tooltip ({tip} px)")


@scenario()
def feature_grid_tooltip_after_cursortip(run_state: "RunState") -> None:
    """A map tooltip must not hide the next Feature-grid tooltip.

    The map picker and panel controls used to share one RML element. Moving from
    a placed tree to its definition cell therefore made the map-picker update
    race the cell's mouseover handler and intermittently hide its tooltip.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    zoom_map(run_state, point=(spot_x, spot_y))
    run_state.click(spot_x, spot_y, delay=Delay.DIALOG)
    run_state.key("Escape", delay=Delay.FRAME)

    # First show the world-object tooltip, then cross straight into the grid.
    run_state.move(spot_x, spot_y, delay=Delay.READY)
    world_tip = run_state.screenshot("world-tooltip")
    if run_state.count_color(world_tip, _tip_box(spot_x, spot_y), TOOLTIP_COLOR) < 500:
        raise AssertionError("placed feature did not show its world tooltip")

    grid_tip_x, grid_tip_y = panel_point(left, OBJECTS["feature_first_tree"])
    run_state.move(grid_tip_x, grid_tip_y, delay=Delay.READY)
    grid_tip = run_state.screenshot("grid-tooltip-after-world")
    # The panel tooltip starts 12px right and 18px below the pointer. This box
    # excludes the thumbnail itself, so its near-black background is decisive.
    grid_tip_box = (grid_tip_x + 12, grid_tip_y + 18, 280, 90)
    if run_state.count_color(grid_tip, grid_tip_box, TOOLTIP_COLOR) < 300:
        raise AssertionError("Feature grid tooltip disappeared after world tooltip")
