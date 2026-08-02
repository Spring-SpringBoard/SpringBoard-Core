"""Objects -> Feature brush scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import OBJECTS, panel_point, window_size
from e2e.scenarios.helpers.objects import arm_tree as _arm_tree
from e2e.scenarios.helpers.objects import open_object_editor as _open
from e2e.scenarios.helpers.registry import scenario

from .common import _placed, _spread

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario(crop="right-panel")
def brush_size(run_state: "RunState") -> None:
    """Feature brushing fills free space, and Shift+wheel resizes its reach.

    A brush is a density tool, not an unconditional object count: a repeat dab
    over an existing selected feature must add nothing. Then an enlarged brush
    must still scatter several features over a wider area. This proves both the
    occupancy check inherited from Chili and the shared Size field.
    """
    run_state.focus()
    left = _open(run_state, "features")
    run_state.click(*panel_point(left, OBJECTS["brush"]), delay=Delay.DIALOG)
    _arm_tree(run_state, left)
    run_state.golden("brush-size-default")

    width, height = window_size(run_state)
    cx, cy = width // 3, height // 2
    zoom_map(run_state, point=(cx, cy))

    # One dab at the default size. A tap, not a hold: the brush repeats every
    # 0.1s while the button is down, so holding it would make the count a
    # stopwatch reading rather than something to assert on.
    mark = len(run_state.commands())
    run_state.press(cx - 260, cy, delay=Delay.POLL)
    run_state.release(cx - 260, cy)
    small = _placed(run_state, mark)

    # The small default brush has exactly one candidate at its centre. Repeating
    # it must see the feature that is already there and leave it alone. This is
    # the important distinction from a fixed-count stamp brush.
    mark = len(run_state.commands())
    run_state.press(cx - 260, cy, delay=Delay.POLL)
    run_state.release(cx - 260, cy)
    occupied = _placed(run_state, mark)

    # Shift+wheel over the map enlarges the brush. Through the root window: a
    # modifier does not survive `xdotool --window`.
    with run_state.modifier("shift"):
        run_state.wheel_root(cx, cy, clicks=5, up=True)
    # The Size field follows the wheel; the screenshot is here to be looked at.
    # The transparent panel background exposes a few map pixels; the control
    # layout itself is stable, while those pixels can vary by a couple dozen.
    run_state.golden("brush-size-enlarged", tolerance=30)

    # A dab with the enlarged brush covers more ground. Occupancy filtering is
    # deliberately allowed to reject candidates, so this is not a brittle fixed
    # count assertion.
    mark = len(run_state.commands())
    run_state.press(cx + 200, cy, delay=Delay.POLL)
    run_state.release(cx + 200, cy)
    large = _placed(run_state, mark)

    if len(small) != 1:
        raise AssertionError(f"default brush placed {len(small)} objects, want 1")
    if occupied:
        raise AssertionError(f"brush added {len(occupied)} feature(s) to an occupied dab")
    if len(large) < 2:
        raise AssertionError(f"enlarged brush placed {len(large)} objects, want at least 2")
    if _spread(large) <= 150:
        raise AssertionError(f"brush did not grow: spread {_spread(large):.0f} world units")
    # Everything on the map is accounted for by the two non-empty dabs.
    if len(_placed(run_state)) != len(small) + len(large):
        raise AssertionError(f"placed {len(_placed(run_state))} objects, want {len(small) + len(large)}")
