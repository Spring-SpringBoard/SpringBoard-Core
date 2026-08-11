"""Objects -> Selection, movement, and clipboard scenarios."""

import json
from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.driver.utils.models import object_number_close, parse_world_position
from e2e.driver.utils.run_env import command_fields
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import OBJECTS, editor_point, panel_left, panel_point, window_size
from e2e.scenarios.helpers.objects import arm_tree as _arm_tree
from e2e.scenarios.helpers.objects import open_object_editor as _open
from e2e.scenarios.helpers.registry import scenario

from .common import MAP_TOLERANCE, SELECTION_RECTANGLE_COLOR, _placed

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario()
def deselect(run_state: "RunState") -> None:
    """Deselecting has to clear the selection box, not just the selection.

    Three frames of the same camera: the feature alone, the feature selected, and
    the feature after clicking empty ground. The last must look like the first --
    a box still drawn there is a selection the editor thinks it still has.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    cx, cy = width // 3, height // 2
    zoom_map(run_state, point=(cx, cy))
    run_state.click(cx, cy, delay=Delay.READY)  # place it
    run_state.key("Escape", delay=Delay.DIALOG)  # leave placement mode
    # Park the cursor away from the feature: every frame is captured with it
    # here, so the pointer itself never shows up in the comparisons.
    run_state.move(cx + 450, cy - 250, delay=Delay.DIALOG)
    unselected = run_state.golden("feature-unselected", crop=None, tolerance=MAP_TOLERANCE)

    # The box is drawn in pure green, and nothing else on the map is: counting
    # those pixels says whether the box is there, where comparing whole frames
    # would just measure the map's own render noise.
    around_feature = (cx - 160, cy - 160, 320, 320)
    if run_state.count_color(unselected, around_feature) != 0:
        raise AssertionError("a selection box before anything was selected")

    run_state.click(cx, cy, delay=Delay.DIALOG)  # select it
    run_state.move(cx + 450, cy - 250, delay=Delay.DIALOG)
    selected = run_state.golden("feature-selected", crop=None, tolerance=MAP_TOLERANCE)
    box = run_state.count_color(selected, around_feature)
    if box < 100:
        raise AssertionError(f"clicking the feature drew no selection box ({box} px)")

    # Escape drops the selection.
    run_state.key("Escape", delay=Delay.DIALOG)
    escaped = run_state.golden("feature-escaped", crop=None, tolerance=MAP_TOLERANCE)
    left = run_state.count_color(escaped, around_feature)
    if left != 0:
        raise AssertionError(f"Escape left the selection box behind ({left} px)")

    # And so does clicking empty ground -- well clear of the panel and of the dev
    # console along the bottom, since a click on either is not a click on the map.
    run_state.click(cx, cy, delay=Delay.DIALOG)  # select it again
    run_state.move(cx + 450, cy - 250, delay=Delay.DIALOG)
    run_state.click(cx + 450, cy - 250, delay=Delay.DIALOG)
    run_state.move(cx + 450, cy - 250, delay=Delay.DIALOG)
    cleared = run_state.golden("feature-deselected", crop=None, tolerance=MAP_TOLERANCE)
    left = run_state.count_color(cleared, around_feature)
    if left != 0:
        raise AssertionError(f"clicking empty ground left the box behind ({left} px)")

    # A box-select, and then a box-select over empty ground: the second one
    # selects nothing, so it must drop what the first one selected. This is the
    # path that leaves a screen full of boxes for objects that are not selected.
    run_state.press(cx - 220, cy - 200)
    run_state.move(cx + 200, cy + 160, delay=Delay.FRAME)
    run_state.release(cx + 200, cy + 160)
    run_state.move(cx + 450, cy - 250, delay=Delay.DIALOG)
    boxed = run_state.golden("box-selected", crop=None, tolerance=MAP_TOLERANCE)
    box = run_state.count_color(boxed, around_feature)
    if box < 100:
        raise AssertionError(f"the box-select selected nothing ({box} px)")

    run_state.press(cx + 350, cy + 200)
    run_state.move(cx + 600, cy + 380, delay=Delay.FRAME)
    run_state.release(cx + 600, cy + 380)
    run_state.move(cx + 450, cy - 250, delay=Delay.DIALOG)
    empty_boxed = run_state.golden("box-selected-empty", crop=None, tolerance=MAP_TOLERANCE)
    left = run_state.count_color(empty_boxed, around_feature)
    if left != 0:
        raise AssertionError(f"a box-select over empty ground kept the old selection ({left} px)")


@scenario()
def rotation(run_state: "RunState") -> None:
    """Ctrl-drag rotates the selection about its centre, as the Lua state does.

    Two features, placed apart and both selected: rotating the pair swings them
    around the midpoint between them, so the rotation is plainly visible on the
    map as well as provable from the commands. One object alone would only change
    its facing, which a tree barely shows.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    cx, cy = width // 3, height // 2
    zoom_map(run_state, point=(cx, cy))

    # Two trees, far apart: rotating a *pair* swings each one around the midpoint
    # between them, and the further apart they are the further they travel. Close
    # together, the ghosts land on top of the originals and the capture shows
    # nothing -- the screen has to make the feature visible, not merely contain it.
    run_state.click(cx - 240, cy, delay=Delay.READY)
    run_state.click(cx + 240, cy, delay=Delay.READY)
    run_state.key("Escape", delay=Delay.SETTLE)  # leave placement mode

    # Box-select both.
    run_state.press(cx - 330, cy - 200)
    run_state.move(cx + 330, cy + 180, delay=Delay.FRAME)
    run_state.release(cx + 330, cy + 180)
    run_state.move(cx + 560, cy + 320, delay=Delay.DIALOG)
    run_state.golden("before-rotate", crop=None, tolerance=MAP_TOLERANCE)

    # Ctrl held, the cursor swings about the centre with the button down: the
    # objects follow it as a preview, and the release commits. The button has to
    # be held -- the engine only delivers mouse-move to the plugin during a drag.
    with run_state.modifier("ctrl"):
        run_state.press(cx + 200, cy)
        # Three moves, and the capture only after the third. The first is consumed
        # by the default state (it is what enters the rotate), and the second only
        # seeds the rotate's baseline angle -- by definition a zero rotation, whose
        # ghosts sit exactly on the originals. Capturing there shows nothing and
        # would have frozen an empty frame as the reference.
        run_state.move(cx + 140, cy - 140, delay=Delay.FRAME)
        run_state.move(cx + 40, cy - 190, delay=Delay.FRAME)
        run_state.move(cx - 190, cy - 60, delay=Delay.SETTLE)
        # park=False: the button is down and the ghosts track the cursor -- moving
        # it would rotate them somewhere else and end the drag off target.
        run_state.golden("rotating", crop=None, tolerance=MAP_TOLERANCE, park=False)
        run_state.move(cx - 200, cy, delay=Delay.SETTLE)
        run_state.release(cx - 200, cy)

    run_state.golden("rotated", crop=None, tolerance=MAP_TOLERANCE)
    # Both objects are committed, once each: `key` carries the whole pose (the
    # command's many-fields form, as Lua's rotate state sends it).
    run_state.assert_command_count("SetObjectParamCommand", 2)

    # And they really swung around the midpoint. Asserted on the *positions*, not
    # the facing: the trees are placed with a random yaw, so "dir is not +z" was
    # already true before the drag -- that assertion passed without the rotation
    # doing anything at all.
    placed = [(pos["x"], pos["z"]) for pos in _placed(run_state)]
    moved: list[tuple[float, float]] = []
    for entry in run_state.case_commands():
        data = entry["data"]
        if data.get("className") != "SetObjectParamCommand" or data.get("__preview"):
            continue
        key = command_fields(data).get("key")
        if not isinstance(key, dict):
            continue
        position = parse_world_position(key.get("pos"))
        if position is not None:
            moved.append((position["x"], position["z"]))
    if len(placed) != 2 or len(moved) != 2:
        raise AssertionError(f"expected 2 placed and 2 moved, got {placed} {moved}")
    # The pair was placed level (same z); a rotation has to break that.
    spread_before = abs(placed[0][1] - placed[1][1])
    spread_after = abs(moved[0][1] - moved[1][1])
    if spread_after <= spread_before + 100:
        raise AssertionError(f"the pair did not rotate: z-spread {spread_before:.0f} -> {spread_after:.0f}")


@scenario()
def selection_drag(run_state: "RunState") -> None:
    """Shift-click extends selection and a plain drag moves the whole set.

    This is intentionally separate from Ctrl-drag rotation: it exercises the
    default state's click modifier path and the move state that follows it. Two
    selected trees make both facts observable: one property edit and one drag
    must each commit two positions, while the in-progress drag has visible
    textured ghosts before the release.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    cx, cy = width // 3, height // 2
    first = (cx - 190, cy)
    second = (cx + 190, cy)
    zoom_map(run_state, point=(cx, cy))
    run_state.click(*first, delay=Delay.READY)
    run_state.click(*second, delay=Delay.READY)
    run_state.key("Escape", delay=Delay.SETTLE)

    # A plain click replaces the selection; Shift-click extends it. Hold Shift
    # physically across the click -- `xdotool --window shift+click` loses the
    # modifier state before Spring receives the mouse event.
    run_state.click(*first, delay=Delay.DIALOG)
    with run_state.modifier("shift"):
        run_state.click(*second, delay=Delay.READY)
    run_state.move(cx + 440, cy + 250, delay=Delay.SETTLE)
    selected = run_state.screenshot("shift-two-selected")
    both_boxes = run_state.count_color(selected, (cx - 300, cy - 170, 600, 340))
    if both_boxes < 200:
        raise AssertionError(f"Shift-click did not visibly select both features ({both_boxes} px)")

    # Drag while the objects are still at their known placement hit points. The
    # drag state moves the complete selection by the anchor's cursor delta.
    mark = len(run_state.commands())
    run_state.press(*first)
    run_state.move(first[0] - 100, first[1] - 120, delay=Delay.FRAME)
    run_state.move(first[0] - 180, first[1] - 150, delay=Delay.FRAME)
    # The ghosts follow the pointer. Do not park it: that would change the
    # preview we are trying to capture.
    run_state.screenshot("dragging-two-features")
    run_state.release(first[0] - 180, first[1] - 150, delay=Delay.READY)
    run_state.move(cx + 440, cy + 250, delay=Delay.SETTLE)
    run_state.screenshot("dragged-two-features")
    moved_by_drag = [
        entry
        for entry in run_state.commands()[mark:]
        if entry["data"].get("className") == "SetObjectParamCommand"
        and entry["data"].get("key") == "pos"
        and not entry["data"].get("__preview")
    ]
    if len(moved_by_drag) != 2:
        raise AssertionError(f"drag moved {len(moved_by_drag)} objects, want 2")

    # Properties fan a shared Pos edit out to every selected object. A numeric
    # drag avoids relying on synthetic text input here, while still exercising
    # the same average-position delta semantics used by a typed value.
    run_state.click(*editor_point(left, "objects", "properties"), delay=Delay.READY)
    run_state.screenshot("properties-multiselected")
    mark = len(run_state.commands())
    pos_x = panel_point(left, OBJECTS["property_pos_x"])
    run_state.press(*pos_x)
    run_state.move_relative(120)
    run_state.screenshot("properties-pos-dragging")
    run_state.release(*pos_x, delay=Delay.READY)
    moved_by_field = [
        entry
        for entry in run_state.commands()[mark:]
        if entry["data"].get("className") == "SetObjectParamCommand"
        and entry["data"].get("key") == "pos"
        and not entry["data"].get("__preview")
    ]
    if len(moved_by_field) != 2:
        raise AssertionError(f"shared Pos X edit affected {len(moved_by_field)} objects, want 2")


@scenario()
def object_actions(run_state: "RunState") -> None:
    """Copy, Paste, Cut, Delete, and Undo/Redo drive live selected features.

    The action layer has direct integration tests, but this scenario owns the
    native hotkey path and the observable engine result. Every destructive step
    is followed by undo/redo or paste, so a command merely reaching the bridge
    cannot satisfy it.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    cx, cy = width // 3, height // 2
    source = (cx - 160, cy)
    target = (cx + 240, cy + 110)
    zoom_map(run_state, point=(cx, cy))
    run_state.click(*source, delay=Delay.READY)
    # Wait for the native object mirror before tracing the new feature.
    run_state.control.wait_for_update()
    run_state.key("Escape", delay=Delay.SETTLE)
    run_state.control.wait_for_update()
    run_state.click(*source, delay=Delay.DIALOG)

    # Copy does not mutate the map; Paste at a different ground point must add
    # an actual feature there. The bridge records an action's grouped children
    # as one CompoundCommand, so the map frame is the engine-facing proof.
    run_state.key("ctrl+c", delay=Delay.SETTLE)
    try:
        copied = json.loads(run_state.clipboard())
    except json.JSONDecodeError as error:
        raise AssertionError("Copy did not put JSON on the system clipboard") from error
    if copied.get("format") != "sbc-editor-objects" or copied.get("version") != 1:
        raise AssertionError(f"Copy wrote an unknown object clipboard format: {copied!r}")
    objects = copied.get("objects")
    if not isinstance(objects, list) or len(objects) != 1 or objects[0].get("kind") != "feature":
        raise AssertionError(f"Copy did not serialize the selected feature: {copied!r}")
    if "__modelID" in objects[0].get("object", {}):
        raise AssertionError("Copy leaked the feature's model ID into system clipboard JSON")

    # A valid empty external payload must replace the process-local cache. This
    # proves Ctrl+V reads the system clipboard rather than only the previous
    # Ctrl+C in this SBC process.
    run_state.set_clipboard(json.dumps({"format": "sbc-editor-objects", "version": 1, "objects": []}))
    mark = len(run_state.commands())
    run_state.key("ctrl+v", delay=Delay.SETTLE)
    if any(entry["data"].get("className") == "CompoundCommand" for entry in run_state.commands()[mark:]):
        raise AssertionError("Paste ignored the empty system object clipboard")

    run_state.set_clipboard(json.dumps(copied))
    mark = len(run_state.commands())
    before_paste = run_state.screenshot("copy-source")
    run_state.move(*target, delay=Delay.FRAME)
    run_state.key("ctrl+v", delay=Delay.READY)
    pasted = run_state.screenshot("copied-and-pasted")
    if not any(entry["data"].get("className") == "CompoundCommand" for entry in run_state.commands()[mark:]):
        raise AssertionError("Paste did not dispatch its grouped native command")
    run_state.assert_screenshot_pixels(before_paste, pasted, min_changed=400)

    # The copied feature must land beneath the cursor. Selecting exactly that
    # point is stronger than the map-pixel change above: a bottom/top-origin
    # ray mismatch still adds a tree, just at the vertically mirrored position.
    run_state.click(*target, delay=Delay.DIALOG)
    selected_paste = run_state.screenshot("pasted-selected")
    around_target = (target[0] - 160, target[1] - 160, 320, 320)
    if run_state.count_color(selected_paste, around_target) < 100:
        raise AssertionError("Paste did not place the feature below the cursor")

    # Cut the pasted selection, then Undo/Redo it. The final undo leaves both
    # features in the world so Delete can exercise the original separately.
    mark = len(run_state.commands())
    run_state.key("ctrl+x", delay=Delay.READY)
    cut = run_state.screenshot("cut")
    if not any(entry["data"].get("className") == "CompoundCommand" for entry in run_state.commands()[mark:]):
        raise AssertionError("Cut did not dispatch its grouped native command")
    run_state.key("ctrl+z", delay=Delay.READY)
    run_state.assert_any_command("UndoCommand")
    restored = run_state.screenshot("cut-undone")
    run_state.assert_screenshot_pixels(cut, restored, min_changed=400)
    run_state.key("ctrl+y", delay=Delay.READY)
    run_state.assert_any_command("RedoCommand")
    redone = run_state.screenshot("cut-redone")
    run_state.assert_screenshot_pixels(restored, redone, min_changed=400)
    run_state.key("ctrl+z", delay=Delay.READY)

    # Undo restores the source but not its UI selection. Select it again, then
    # Delete and undo it once more: Delete is a distinct hotkey/action, not an
    # alias for Cut with an empty clipboard.
    run_state.click(*source, delay=Delay.DIALOG)
    mark = len(run_state.commands())
    run_state.key("Delete", delay=Delay.READY)
    deleted = run_state.screenshot("deleted")
    if not any(entry["data"].get("className") == "CompoundCommand" for entry in run_state.commands()[mark:]):
        raise AssertionError("Delete did not dispatch its grouped native command")
    run_state.key("ctrl+z", delay=Delay.READY)
    undeleted = run_state.screenshot("delete-undone")
    run_state.assert_screenshot_pixels(deleted, undeleted, min_changed=400)


@scenario()
def selection(run_state: "RunState") -> None:
    """Rectangle select: drag from sky over a placed feature and cancel it.

    Starting outside terrain matters: Chili permits the first corner over the
    sky, then selects objects by their screen positions. A right click during
    the gesture must also discard the transient box; otherwise it captures all
    later map input. The completed box must select the feature, which is proved
    by editing it in Properties afterwards.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    zoom_map(run_state, point=(spot_x, spot_y))
    run_state.click(spot_x, spot_y, delay=Delay.READY)  # place it
    run_state.key("Escape", delay=Delay.SETTLE)  # leave placement mode

    # A non-left press cancels a live box-select. Keep left held while making
    # the right click: this is the input sequence that previously left the
    # rectangle state permanently active.
    run_state.press(spot_x - 220, 80)
    run_state.move(spot_x + 120, spot_y + 60, delay=Delay.FRAME)
    run_state.move(spot_x + 200, spot_y + 160, delay=Delay.SETTLE)
    run_state.click(spot_x + 500, spot_y + 300, button=3, delay=Delay.SETTLE)
    cancelled = run_state.screenshot("box-right-cancelled")
    map_region = (0, 70, width - 500, height - 170)
    lingering = run_state.count_color(
        cancelled,
        map_region,
        SELECTION_RECTANGLE_COLOR,
        fuzz="5%",
    )
    if lingering > 100:
        raise AssertionError(f"right click left the rectangle-select outline behind ({lingering} px)")
    run_state.release(spot_x + 500, spot_y + 300)

    # Start in the sky, well above the map polygon, then sweep down-right over
    # the feature. This used to fail in the Rust port because it required the
    # first corner to trace to ground. Continue the same map-owned gesture over
    # the panel and release there: UI hit-testing must not hide its movement or
    # steal its release.
    run_state.press(spot_x - 220, 80)
    run_state.move(spot_x + 120, spot_y + 60, delay=Delay.FRAME)
    run_state.move(spot_x + 200, spot_y + 160, delay=Delay.SETTLE)
    # park=False: the box is drawn to the cursor, so it *is* the cursor position.
    run_state.golden("box-dragging", crop=None, tolerance=MAP_TOLERANCE, park=False)

    release_x = panel_left(run_state) + 250
    release_y = spot_y + 160
    run_state.move(release_x, release_y, delay=Delay.SETTLE)
    crossing = run_state.screenshot("box-over-panel")
    crossing_outline = run_state.count_color(
        crossing,
        (0, 70, panel_left(run_state), height - 170),
        SELECTION_RECTANGLE_COLOR,
        fuzz="5%",
    )
    if crossing_outline < 100:
        raise AssertionError("rectangle-select stopped updating after the pointer crossed a panel")
    run_state.release(release_x, release_y)
    run_state.move(spot_x + 400, spot_y + 300, delay=Delay.DIALOG)
    selected = run_state.screenshot("box-selected")
    lingering = run_state.count_color(
        selected,
        (0, 70, panel_left(run_state), height - 170),
        SELECTION_RECTANGLE_COLOR,
        fuzz="5%",
    )
    if lingering > 100:
        raise AssertionError(f"release over a panel left the rectangle-select outline behind ({lingering} px)")
    run_state.golden("box-selected", crop=None, tolerance=MAP_TOLERANCE)

    # Properties edits the *selected* object. If the box selected nothing, there
    # is nothing to edit and no command is emitted.
    run_state.click(*editor_point(left, "objects", "properties"), delay=Delay.READY)
    run_state.golden("props-after-box-select", crop="right-panel")
    run_state.fill_text(
        *panel_point(left, OBJECTS["property_pos_x"]),
        "1800",
        click_delay=Delay.SETTLE,
        commit_delay=Delay.READY,
    )
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=object_number_close("x", 1800, tolerance=1.0),
    )
