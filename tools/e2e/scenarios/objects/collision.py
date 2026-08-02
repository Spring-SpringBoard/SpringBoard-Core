"""Objects -> Collision scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.driver.utils.models import is_object
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import OBJECTS, editor_point, panel_point, window_size
from e2e.scenarios.helpers.objects import arm_tree as _arm_tree
from e2e.scenarios.helpers.objects import open_object_editor as _open
from e2e.scenarios.helpers.registry import scenario

from .common import MAP_TOLERANCE

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario()
def collision(run_state: "RunState") -> None:
    """Objects -> Collision, on its own so it is quick and focused.

    The point of the editor is the *volume*, so the volume is what gets checked:
    turn on the debug rendering and prove that each edit visibly changes the
    shape drawn on the object. A command reaching the bridge would not tell us
    the volume actually moved.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    zoom_map(run_state, point=(spot_x, spot_y))
    run_state.click(spot_x, spot_y, delay=Delay.READY)  # place
    run_state.key("Escape", delay=Delay.DIALOG)
    run_state.click(spot_x, spot_y, delay=Delay.READY)  # select it

    run_state.click(*editor_point(left, "objects", "collision"), delay=Delay.READY)
    hidden = run_state.golden("volume-hidden", crop=None, tolerance=MAP_TOLERANCE)

    volume_visible = False
    try:
        # Show volume: the collision shape is drawn over the object.
        run_state.click(*panel_point(left, OBJECTS["collision_show_volume"]), delay=Delay.READY)
        volume_visible = True
        shown = run_state.golden("volume-shown", crop=None, tolerance=MAP_TOLERANCE)
        volume_region = (spot_x - 260, spot_y - 260, 520, 520)
        run_state.assert_region_pixels(hidden, shown, volume_region, min_changed=300)

        # Scaling the volume must redraw it bigger, not merely emit a command.
        run_state.fill_text(
            *panel_point(left, OBJECTS["collision_scale_x"]),
            "120",
            click_delay=Delay.SETTLE,
            commit_delay=Delay.READY,
        )
        scaled = run_state.golden("volume-scaled", crop=None, tolerance=MAP_TOLERANCE)
        run_state.assert_any_command(
            "SetObjectParamCommand",
            key="collision",
            value=is_object,
        )
        run_state.assert_region_pixels(shown, scaled, volume_region, min_changed=300)

        # Blocking is a Collision-owned composite. One toggle must submit the whole
        # table, not a bare boolean; Properties deliberately has no duplicate copy.
        run_state.click(*panel_point(left, OBJECTS["collision_blocking"]), delay=Delay.DIALOG)
        run_state.assert_any_command(
            "SetObjectParamCommand",
            key="blocking",
            value=is_object,
        )
    finally:
        if volume_visible:
            run_state.click(*panel_point(left, OBJECTS["collision_show_volume"]), delay=Delay.POLL)
