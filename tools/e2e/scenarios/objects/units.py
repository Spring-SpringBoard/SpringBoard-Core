"""Objects -> Units and feature placement scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import OBJECTS, dropdown_option, panel_point, window_size
from e2e.scenarios.helpers.objects import arm_tree as _arm_tree
from e2e.scenarios.helpers.objects import open_object_editor as _open
from e2e.scenarios.helpers.registry import scenario

from .common import MAP_TOLERANCE

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario(crop="right-panel")
def units_panel(run_state: "RunState") -> None:
    """Objects -> Units and Features: the def grid, its filters, and placement.

    The engine's standalone boot has feature defs but no unit defs, so the grid
    and placement are exercised on Features; the Units view is captured to show
    its own filters (Type + Terrain, no Wreck).
    """
    run_state.focus()
    left = _open(run_state, "units")
    run_state.golden("units-open")

    left = _open(run_state, "features")
    # Default filters (Type=Other) show the non-wreck defs: the trees and the
    # geovent. Their thumbnails are the real models, rendered through the
    # engine's model shader.
    run_state.golden("features-open")

    # Brush mode swaps the placement fields: Lua hides `amount` and shows size,
    # spread, noise and the min/max rotation of all three axes.
    run_state.click(*panel_point(left, OBJECTS["brush"]), delay=Delay.DIALOG)
    # The transparent shell exposes a few map pixels behind the panel.
    run_state.golden("features-brush-fields", tolerance=30)
    run_state.click(*panel_point(left, OBJECTS["add"]), delay=Delay.DIALOG)

    # Arm a tree and place it. The command must reach the bridge *and* the
    # feature must actually appear on the map -- so these two are captured
    # full-frame, where the map is visible. A tree rather than the first cell
    # (`geovent`), because a tree is recognisably a tree in the capture.
    _arm_tree(run_state, left)
    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    # The default camera is far enough out that a tree is a few pixels; frame
    # the map through the control API so it can be seen in the capture.
    zoom_map(run_state, point=(spot_x, spot_y))
    before = run_state.golden("before-place", crop=None, tolerance=MAP_TOLERANCE)
    run_state.click(spot_x, spot_y, delay=Delay.READY)
    run_state.key("Escape", delay=Delay.SETTLE)  # leave placement mode
    run_state.move(spot_x + 260, spot_y + 220, delay=Delay.DIALOG)
    after = run_state.golden("feature-placed", crop=None, tolerance=MAP_TOLERANCE)

    run_state.assert_command("AddObjectCommand", objType="feature")
    run_state.assert_screenshot_pixels(before, after, min_changed=400)

    # Amount places that many objects, and the ghosts preview exactly where they
    # will land: the preview and the placement must not disagree.
    run_state.click(*panel_point(left, OBJECTS["feature_first_tree"]), delay=Delay.SETTLE)
    run_state.fill_text(
        *panel_point(left, OBJECTS["feature_amount"]),
        "5",
        click_delay=Delay.FRAME,
        commit_delay=Delay.DIALOG,
    )
    run_state.move(spot_x - 260, spot_y, delay=Delay.DIALOG)
    # park=False: the ghosts follow the cursor, so moving it out of shot would
    # move the very thing being captured.
    run_state.golden("amount-5-preview", crop=None, tolerance=MAP_TOLERANCE, park=False)
    before5 = run_state.golden("before-amount-5", crop=None, tolerance=MAP_TOLERANCE)
    run_state.click(spot_x - 260, spot_y, delay=Delay.LOAD)
    run_state.key("Escape", delay=Delay.SETTLE)
    run_state.move(spot_x + 400, spot_y + 300, delay=Delay.DIALOG)
    after5 = run_state.golden("amount-5-placed", crop=None, tolerance=MAP_TOLERANCE)
    run_state.assert_screenshot_pixels(before5, after5, min_changed=800)
    run_state.assert_command_count("AddObjectCommand", 6)  # 1 earlier + 5 now

    # Type = Wreckage. None of this map's features are wrecks, so the grid must
    # empty -- the filter proving it filters, not merely that it renders.
    run_state.click(*panel_point(left, OBJECTS["feature_type"]), delay=Delay.SETTLE)
    run_state.click(*panel_point(left, dropdown_option(OBJECTS["feature_type"], 1)), delay=Delay.READY)
    run_state.golden("features-wreckage-empty")
