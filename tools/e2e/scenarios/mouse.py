"""Physical-mouse coverage for the panel and for the screen-to-world contract.

Most scenarios reach the editors through the typed control channel, which never
touches the engine's mouse callins. These two do the opposite: every input here
is a real X11 event, and the assertions read the resulting state back through
the control channel. They carry no goldens, so they stay cheap enough to run on
every suite.
"""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import (
    MAP,
    OBJECTS,
    TAB_X,
    TAB_Y,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)
from e2e.scenarios.helpers.objects import arm_tree as _arm_tree
from e2e.scenarios.helpers.objects import open_object_editor as _open
from e2e.scenarios.helpers.registry import scenario
from e2e.scenarios.objects.common import _placed

if TYPE_CHECKING:
    from e2e.driver.state import RunState

# A click and the ray query for the same pixel describe the same spot. The
# budget covers the brush's own rounding, not a different point on the map: a
# mirrored y lands hundreds of units away even near the middle of the view.
TRACE_TOLERANCE = 40.0


@scenario()
def mouse_ui(run_state: "RunState") -> None:
    """The panel, driven only by the pointer.

    Tab, editor button, field click, typed commit and a numeric drag are all
    real X11 input, and the editor model is read back to prove each one landed
    on the control it aimed at. Without this, every editor is reachable in tests
    only through the control channel, which no user has.

    Note what this cannot cover: RmlUi consumes a press over the panel document
    inside the engine, so those clicks never reach the native mouse callin at
    all. The panel's own hit test therefore sees map presses only, and this
    scenario proves the user-facing path rather than that hit test.
    """
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.FRAME)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.READY)

    terrain = run_state.control.editor("heightmapEditor")
    run_state.fill_text(
        *panel_point(left, MAP["terrain_size"]),
        "140",
        click_delay=Delay.FRAME,
        commit_delay=Delay.SETTLE,
    )
    typed = terrain.get("size")
    assert typed == 140.0, f"typing into the Size field gave {typed!r}, want 140.0"

    # A numeric drag pins the pointer and warps it back, so the motion has to be
    # relative. The direction is what matters: the exact value depends on which
    # tick the release meets.
    run_state.press(*panel_point(left, MAP["terrain_size"]))
    run_state.move_relative(60)
    run_state.release(*panel_point(left, MAP["terrain_size"]), delay=Delay.SETTLE)
    dragged = terrain.get("size")
    assert isinstance(dragged, float), f"Size is {dragged!r}, want a number"
    assert dragged > typed, f"dragging right did not raise Size: {typed} -> {dragged}"

    # A press beside the panel belongs to the map, not to the control that was
    # last touched. This is the ownership half of the hit test.
    run_state.fill_text(
        *panel_point(left, MAP["terrain_rotation"]),
        "15",
        click_delay=Delay.FRAME,
        commit_delay=Delay.SETTLE,
    )
    rotation = terrain.get("rotation")
    assert rotation == 15.0, f"the second field took {rotation!r}, want 15.0"
    assert terrain.get("size") == dragged, "editing Rotation moved Size"


@scenario()
def mouse_coordinates(run_state: "RunState") -> None:
    """A click places an object where that pixel points.

    The engine reports mouse callbacks in its own bottom-origin screen space,
    while control clients address the window top-origin like a screenshot. Both
    paths are asked about the same two pixels here, so a future flip on either
    side fails immediately -- and says so, rather than moving a golden's trees.
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
