"""Objects tab: Units, Features, Properties, Collision.

One scenario per editor, each kept to a handful of screens so every one can
actually be looked at. Every step asserts the command that was emitted *and*
the result of it -- a command reaching the bridge does not prove the engine
acted on it.
"""

import json
from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.driver.utils.models import (
    WorldPosition,
    is_object,
    object_number_above,
    object_number_below,
    object_number_close,
    parse_world_position,
)
from e2e.driver.utils.run_env import command_fields

from .helpers.geometry import (
    OBJECTS,
    dropdown_option,
    editor_point,
    panel_point,
    window_size,
)
from .helpers.objects import arm_tree as _arm_tree
from .helpers.objects import open_object_editor as _open
from .helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState

# Differing pixels forgiven when a capture includes the map.
#
# The panel is bit-stable; the map is not. The engine's tree render shimmers
# between runs -- the diff is a fringe around each tree's silhouette, ~700 px per
# tree, and a frame here holds up to four (two objects and their two ghosts).
#
# So a map golden is a *gross* regression check: it catches a ghost that stopped
# drawing or an object that never got placed (many thousands of pixels), and it
# deliberately cannot see a few-hundred-pixel change. The fine detail on the map
# is asserted exactly instead, and without pixels: `count_color` for the green
# selection box, and the command log for what was actually sent.
MAP_TOLERANCE = 4000

# The transient rectangle-select outline is alpha-blended over the map. This is
# its resulting colour on the default green terrain, distinct from the pure
# green boxes that mark selected objects.
SELECTION_RECTANGLE_COLOR = "#45b0e6"

# The cursor tooltip's background (`.native-tooltip` in ui.rcss). Near-black, and
# nothing on the map is, so counting these pixels says whether the tip is drawn.
TOOLTIP_COLOR = "#0b0d0c"


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
    # The default camera is far enough out that a tree is a few pixels; zoom in
    # so the placed feature can actually be seen in the capture.
    run_state.wheel(spot_x, spot_y, clicks=8, up=True)
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
    run_state.golden("props-drag-released-outside", tolerance=220)

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
    run_state.wheel(spot_x, spot_y, clicks=8, up=True)
    run_state.click(spot_x, spot_y, delay=Delay.READY)  # place
    run_state.key("Escape", delay=Delay.DIALOG)
    run_state.click(spot_x, spot_y, delay=Delay.READY)  # select it

    run_state.click(*editor_point(left, "objects", "collision"), delay=Delay.READY)
    hidden = run_state.golden("volume-hidden", crop=None, tolerance=MAP_TOLERANCE)

    # Show volume: the collision shape is drawn over the object.
    run_state.click(*panel_point(left, OBJECTS["collision_shape"]), delay=Delay.READY)
    shown = run_state.golden("volume-shown", crop=None, tolerance=MAP_TOLERANCE)
    run_state.assert_screenshot_pixels(hidden, shown, min_changed=300)

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
    run_state.assert_screenshot_pixels(shown, scaled, min_changed=300)

    # A different volume type is a different shape on screen.
    run_state.click(*panel_point(left, OBJECTS["collision_type"]), delay=Delay.SETTLE)
    run_state.click(*panel_point(left, dropdown_option(OBJECTS["collision_type"], 1)), delay=Delay.READY)
    typed = run_state.golden("volume-type-changed", crop=None, tolerance=MAP_TOLERANCE)
    run_state.assert_screenshot_pixels(scaled, typed, min_changed=200)
    # The fields live in the panel, so crop to it: a full-frame shot would drag
    # the map's render noise into a comparison that is about a form.
    run_state.golden("collision-fields", crop="right-panel")

    # Blocking is a Collision-owned composite. One toggle must submit the whole
    # table, not a bare boolean; Properties deliberately has no duplicate copy.
    run_state.click(*panel_point(left, OBJECTS["collision_blocking"]), delay=Delay.DIALOG)
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="blocking",
        value=is_object,
    )


@scenario(env={"SBC_HIDE_TOOLTIPS": "0"})
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
    run_state.wheel(spot_x, spot_y, clicks=8, up=True)
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


@scenario(env={"SBC_HIDE_TOOLTIPS": "0"})
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
    run_state.wheel(spot_x, spot_y, clicks=8, up=True)
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
    run_state.wheel(cx, cy, clicks=8, up=True)  # zoom in on the map

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
    run_state.wheel(cx, cy, clicks=8, up=True)
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

    run_state.click(cx - 20, cy, delay=Delay.DIALOG)  # select it
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
    run_state.click(cx - 20, cy, delay=Delay.DIALOG)  # select it again
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
    run_state.wheel(cx, cy, clicks=8, up=True)  # zoom in on the spot

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
    for entry in run_state.commands():
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
    run_state.wheel(cx, cy, clicks=8, up=True)
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
    run_state.wheel(cx, cy, clicks=8, up=True)
    run_state.click(*source, delay=Delay.READY)
    run_state.key("Escape", delay=Delay.SETTLE)
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
    run_state.wheel(spot_x, spot_y, clicks=8, up=True)
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
    # first corner to trace to ground.
    run_state.press(spot_x - 220, 80)
    run_state.move(spot_x + 120, spot_y + 60, delay=Delay.FRAME)
    run_state.move(spot_x + 200, spot_y + 160, delay=Delay.SETTLE)
    # park=False: the box is drawn to the cursor, so it *is* the cursor position.
    run_state.golden("box-dragging", crop=None, tolerance=MAP_TOLERANCE, park=False)
    run_state.release(spot_x + 200, spot_y + 160)
    run_state.move(spot_x + 400, spot_y + 300, delay=Delay.DIALOG)
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


def _tip_box(cursor_x: int, cursor_y: int) -> tuple[int, int, int, int]:
    return (cursor_x + 40, cursor_y + 30, 320, 90)


def _placed(run_state: "RunState", since: int = 0) -> list[WorldPosition]:
    positions: list[WorldPosition] = []
    for entry in run_state.commands()[since:]:
        data = entry["data"]
        if data.get("className") != "AddObjectCommand" or data.get("__preview"):
            continue
        params = command_fields(data).get("params")
        if not isinstance(params, dict):
            continue
        position = parse_world_position(params.get("pos"))
        if position is not None:
            positions.append(position)
    return positions


def _spread(placed: list[WorldPosition]) -> float:
    if len(placed) < 2:
        return 0.0
    xs = [pos["x"] for pos in placed]
    zs = [pos["z"] for pos in placed]
    return max(max(xs) - min(xs), max(zs) - min(zs))
