"""Objects -> Properties scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.driver.utils.models import object_number_above, object_number_below, object_number_close
from e2e.scenarios.helpers.geometry import OBJECTS, editor_point, panel_point, window_size
from e2e.scenarios.helpers.objects import arm_tree as _arm_tree
from e2e.scenarios.helpers.objects import open_object_editor as _open
from e2e.scenarios.helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario(crop="right-panel")
def props_panel(run_state: "RunState") -> None:
    """Objects -> Properties and Collision.

    Both edit the *selected* object, so a feature is placed and selected first;
    opening the tab with an empty selection proves nothing.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    run_state.click(spot_x, spot_y, delay=Delay.READY)  # place
    # Escape, rather than re-clicking Add, leaves placement for normal map
    # selection. Add/Brush are choice actions, not on/off toggles.
    run_state.key("Escape", delay=Delay.DIALOG)
    # Clicking where it was placed now selects it: the feature's collision volume
    # sits at its foot, so this is the point the ray actually hits.
    run_state.click(spot_x, spot_y, delay=Delay.READY)
    run_state.move(spot_x + 260, spot_y + 220, delay=Delay.SETTLE)
    run_state.golden("feature-selected")
    run_state.assert_command("AddObjectCommand", objType="feature")

    run_state.click(*editor_point(left, "objects", "properties"), delay=Delay.READY)
    run_state.golden("props-open")

    # Pos X. The whole vector is sent, not the one axis, and the object must
    # actually move on the map.
    before = run_state.golden("before-move")
    run_state.fill_text(
        *panel_point(left, OBJECTS["property_pos_x"]),
        "1500",
        click_delay=Delay.SETTLE,
        commit_delay=Delay.READY,
    )
    run_state.move(spot_x + 260, spot_y + 220, delay=Delay.SETTLE)
    after = run_state.golden("props-pos-edited")
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=object_number_close("x", 1500, tolerance=1.0),
    )
    # The panel redraws the field with the new value. Only ~300 px: the shots are
    # cropped to the panel and the cursor is parked out of both, so this measures
    # the text changing and nothing else.
    run_state.assert_screenshot_pixels(before, after, min_changed=200)

    # Dragging a numeric field changes it without ever entering text mode, and
    # commits once on release. The drag pins the pointer and warps it back after
    # every move (as content-creation tools do), so the motion has to be
    # relative -- absolute moves would fight the warp.
    run_state.press(*panel_point(left, OBJECTS["property_pos_x"]))
    run_state.move_relative(120)
    # Mid-drag: the pointer is pinned to where the drag began and drawn as the
    # empty cursor, so nothing follows the mouse across the panel. park=False --
    # moving the pointer now would fight the drag's own warp and end it.
    # Relative packets make only the live numeric glyphs vary by a few pixels;
    # the no-cursor drag frame itself must remain visually stable.
    run_state.golden("props-pos-dragging", park=False, tolerance=150)
    run_state.release(*panel_point(left, OBJECTS["property_pos_x"]))
    # The pinned relative drag may land within one input packet of its nominal
    # value (for example 1580 vs. 1600); the command assertion below owns the
    # behavioural bound, while this frame still catches layout regressions.
    run_state.golden("props-pos-dragged", tolerance=150)
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=object_number_above("x", 1500.5),
    )

    # Releasing a drag with the pointer far outside the panel must still end it:
    # RmlUi's drag capture delivers `dragend` wherever the button comes up, and
    # nothing else can (the engine never hands the plugin a release for a press
    # the panel's RmlUi consumed).
    run_state.press(*panel_point(left, OBJECTS["property_pos_x"]))
    # Take a comfortably large move: packet batching may consume only part of a
    # nominal delta, but the committed position must cross back below 1500.
    run_state.move_relative(-800, 260)  # out over the map
    run_state.release(left - 300, 500)
    dragged = run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=object_number_below("x", 1500.0),
    )
    # Now moving the mouse must not keep changing it: the drag is over.
    run_state.move(left - 600, 500, delay=Delay.SETTLE)
    run_state.assert_no_command_after(dragged, "SetObjectParamCommand", key="pos")
    # Relative drag deltas are packeted by the input backend. The assertions
    # above prove it moved left and stopped after release; this screenshot pins
    # the released visual state without requiring one exact numeric delta.
    run_state.golden("props-drag-released-outside", tolerance=260)

    # Collision fields, including the blocking toggles, belong exclusively to
    # the Collision scenario rather than being duplicated in Properties.
    #
    # Last, because it deselects: clicking empty ground with an object editor
    # open used to abort the engine -- the panel wrote through element handles
    # RmlUi had already destroyed. It must survive, and clear the selection.
    for dx, dy in ((-300, -150), (250, 120), (-120, 260), (380, -220)):
        run_state.click(spot_x + dx, spot_y + dy, delay=Delay.SETTLE)
    run_state.golden("props-after-map-clicks")
    run_state.assert_running()
