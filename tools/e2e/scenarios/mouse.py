"""Physical-mouse coverage for the screen-to-world contract.

Most scenarios reach the editors through the typed control channel, which never
touches the engine's mouse callins at all. This one does the opposite: the input
is real X11, and the result is read back through the control channel. It carries
no golden, so a vertical flip is reported as two coordinates rather than as a
picture full of moved trees.
"""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import OBJECTS, panel_point, window_size
from e2e.scenarios.helpers.objects import arm_tree as _arm_tree
from e2e.scenarios.helpers.objects import open_object_editor as _open
from e2e.scenarios.helpers.registry import scenario
from e2e.scenarios.objects.common import _placed

if TYPE_CHECKING:
    from e2e.driver.state import RunState

# A click and the ray query for the same pixel describe the same spot. The
# budget covers the placement's own rounding, not a different point on the map:
# a mirrored y lands hundreds of units away even near the middle of the view.
TRACE_TOLERANCE = 40.0


@scenario()
def mouse_coordinates(run_state: "RunState") -> None:
    """A click places an object where that pixel points.

    The engine reports mouse callbacks in its own bottom-origin screen space,
    while control clients address the window top-origin like a screenshot. Both
    paths are asked about the same two pixels here, so a flip on either side
    fails immediately and names the two positions it compared.

    This is deliberately the only mouse scenario. The panel and the consoles do
    their hit testing inside RmlUi, which the engine feeds directly: a press
    over either never reaches the native callin, and their ownership checks are
    reached through a pointer-capture state that a scripted click cannot steer.
    A UI-side mouse test therefore passes whatever the coordinate space is,
    while this one cannot.
    """
    run_state.focus()
    left = _open(run_state, "features")
    run_state.click(*panel_point(left, OBJECTS["add"]), delay=Delay.DIALOG)
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    spot_x = width // 3
    zoom_map(run_state, point=(spot_x, height // 2))

    # Two points either side of the middle: a mirrored y is invisible at the
    # centre of the view and grows with the distance from it.
    for label, spot_y in (("upper", height // 3), ("lower", height * 2 // 3)):
        expected = run_state.control.camera.trace_screen_ray(spot_x, spot_y)
        assert expected["hit_type"] == 3, f"{label}: the ray missed the ground: {expected}"
        mark = len(run_state.commands())
        run_state.click_settled(spot_x, spot_y, delay=Delay.SETTLE)
        placed = _placed(run_state, mark)
        assert len(placed) == 1, f"{label}: click placed {len(placed)} objects, want 1"

        want_x, _want_y, want_z = expected["position"]
        got = placed[0]
        drift = max(abs(got["x"] - want_x), abs(got["z"] - want_z))
        assert drift <= TRACE_TOLERANCE, (
            f"{label}: click at ({spot_x}, {spot_y}) placed the feature at "
            f"({got['x']:.0f}, {got['z']:.0f}), but that pixel traces to "
            f"({want_x:.0f}, {want_z:.0f}) -- {drift:.0f} units away"
        )
