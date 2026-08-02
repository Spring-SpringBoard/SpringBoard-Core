"""Objects -> Features grid scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.geometry import OBJECTS, panel_point
from e2e.scenarios.helpers.objects import open_object_editor as _open
from e2e.scenarios.helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario(crop="right-panel")
def def_grid(run_state: "RunState") -> None:
    """Only the Features def grid: the fastest look at thumbnail rendering.

    No placement, no filters, no field edits -- iterating on how the models are
    drawn should not cost a full editor scenario.
    """
    run_state.focus()
    _open(run_state, "features")
    run_state.golden("def-grid")


@scenario(crop="right-panel")
def feature_placement_actions(run_state: "RunState") -> None:
    """Features Add/Brush are persistent choices, even before a def is picked.

    The Brush-only placement controls are a stronger signal than the pressed
    colour alone: a repeated Brush click used to return the editor to its empty
    state when no feature definition was selected.
    """
    run_state.focus()
    left = _open(run_state, "features")

    add = run_state.screenshot("add-selected")
    run_state.click(*panel_point(left, OBJECTS["brush"]), delay=Delay.DIALOG)
    brush = run_state.screenshot("brush-selected")
    # Only the placement controls below the definition grid: thumbnails redraw
    # continuously, so including their area would make this visual assertion
    # flaky for no benefit.
    # `screenshot()` inherits this scenario's right-panel crop, so comparison
    # coordinates are panel-local rather than window-local.
    placement_controls = (0, 700, 500, 300)
    run_state.assert_region_pixels(add, brush, placement_controls, min_changed=300)

    run_state.click(*panel_point(left, OBJECTS["brush"]), delay=Delay.SETTLE)
    brush_again = run_state.screenshot("brush-reselected")
    run_state.assert_region_pixels(brush, brush_again, placement_controls, max_changed=3_000)
