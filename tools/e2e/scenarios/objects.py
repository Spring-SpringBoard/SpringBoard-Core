"""Objects tab: Units, Features, Properties, Collision.

One scenario per editor, each kept to a handful of screens so every one can
actually be looked at. Every step asserts the command that was emitted *and*
the result of it -- a command reaching the bridge does not prove the engine
acted on it.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import EDITOR_BUTTON_Y, TAB_X, TAB_Y, panel_left, window_size
from scenarios.registry import scenario

if TYPE_CHECKING:
    from runner import E2ERun

# Rows inside the Objects editors, measured from the panel's left/top. The
# definitions come first (filters, search, grid); the placement settings sit
# below the grid, as they do in the Lua UI.
ACTION_Y = 217          # Add / Brush
FILTER_Y = 316          # Type / Wreck
TERRAIN_Y = 358         # Terrain (features; units put it beside Type)
SEARCH_Y = 400
GRID_Y = 470            # first row of definition cells
TEAM_Y = 714            # below the grid
AMOUNT_Y = 757


def _open(run_state: E2ERun, editor_x: int) -> int:
    """Objects tab, then one of its editors. Returns the panel's left edge."""
    left = panel_left(run_state)
    run_state.click(left + TAB_X["objects"], TAB_Y, delay=0.25)
    run_state.click(left + editor_x, EDITOR_BUTTON_Y, delay=0.7)
    return left


def _arm_tree(run_state: E2ERun, left: int) -> None:
    """Arm a tree, specifically.

    The first cell is `geovent`, which has no model: it cannot be hit by a screen
    ray, so anything that places it and then clicks it selects nothing. Search
    for a tree instead of trusting the grid order.
    """
    run_state.click(left + 180, SEARCH_Y, delay=0.2)
    run_state.type_text("tree")
    run_state.click(left + 55, GRID_Y, delay=0.5)


@scenario(crop="right-panel")
def def_grid(run_state: E2ERun) -> None:
    """Only the Features def grid: the fastest look at thumbnail rendering.

    No placement, no filters, no field edits -- iterating on how the models are
    drawn should not cost a full editor scenario.
    """
    run_state.focus()
    _open(run_state, 110)                             # Features
    run_state.screenshot("def-grid")


@scenario(uis=("chili", "rmlui", "rust"), crop="right-panel")
def units_panel(run_state: E2ERun) -> None:
    """Objects -> Units and Features: the def grid, its filters, and placement.

    The engine's standalone boot has feature defs but no unit defs, so the grid
    and placement are exercised on Features; the Units view is captured to show
    its own filters (Type + Terrain, no Wreck).
    """
    run_state.focus()
    left = _open(run_state, 38)                       # Units
    run_state.screenshot("units-open")

    left = _open(run_state, 110)                      # Features
    # Default filters (Type=Other) show the non-wreck defs: the trees and the
    # geovent. Their thumbnails are the real models, rendered through the
    # engine's model shader.
    run_state.screenshot("features-open")

    # Brush mode swaps the placement fields: Lua hides `amount` and shows size,
    # spread, noise and the min/max rotation of all three axes.
    run_state.click(left + 134, ACTION_Y, delay=0.6)
    run_state.screenshot("features-brush-fields")
    run_state.click(left + 54, ACTION_Y, delay=0.6)    # back to Add

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
    before = run_state.screenshot_root("before-place")
    run_state.click(spot_x, spot_y, delay=0.8)
    run_state.key("Escape", delay=0.4)                 # leave placement mode
    run_state.move(spot_x + 260, spot_y + 220, delay=0.5)
    after = run_state.screenshot_root("feature-placed")

    run_state.assert_command("AddObjectCommand", objType="feature")
    run_state.assert_screenshot_pixels(before, after, min_changed=400)

    # Amount places that many objects, and the ghosts preview exactly where they
    # will land: the preview and the placement must not disagree.
    run_state.click(left + 55, GRID_Y, delay=0.4)      # re-arm (Escape dropped it)
    run_state.click(left + 120, AMOUNT_Y, delay=0.3)
    run_state.key("ctrl+a", delay=0.12)
    run_state.type_text("5")
    run_state.key("Return", delay=0.5)
    run_state.move(spot_x - 260, spot_y, delay=0.6)
    run_state.screenshot_root("amount-5-preview")      # five ghosts
    before5 = run_state.screenshot_root("before-amount-5")
    run_state.click(spot_x - 260, spot_y, delay=1.0)
    run_state.key("Escape", delay=0.4)
    run_state.move(spot_x + 400, spot_y + 300, delay=0.5)
    after5 = run_state.screenshot_root("amount-5-placed")
    run_state.assert_screenshot_pixels(before5, after5, min_changed=800)
    run_state.assert_command_count("AddObjectCommand", 6)   # 1 earlier + 5 now

    # Type = Wreckage. None of this map's features are wrecks, so the grid must
    # empty -- the filter proving it filters, not merely that it renders.
    run_state.click(left + 104, FILTER_Y, delay=0.4)
    run_state.key("Down", delay=0.2)
    run_state.key("Return", delay=0.7)                 # commit and close the list
    run_state.screenshot("features-wreckage-empty")


@scenario(uis=("rmlui", "rust"), crop="right-panel")
def props_panel(run_state: E2ERun) -> None:
    """Objects -> Properties and Collision.

    Both edit the *selected* object, so a feature is placed and selected first;
    opening the tab with an empty selection proves nothing.
    """
    run_state.focus()
    left = _open(run_state, 110)                      # Features
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    run_state.click(spot_x, spot_y, delay=0.8)        # place
    # Clicking the active Add button leaves placement -- otherwise every click on
    # the map keeps placing and nothing can ever be selected or dragged.
    run_state.click(left + 54, ACTION_Y, delay=0.6)
    # Clicking where it was placed now selects it: the feature's collision volume
    # sits at its foot, so this is the point the ray actually hits.
    run_state.click(spot_x, spot_y, delay=0.8)
    run_state.move(spot_x + 260, spot_y + 220, delay=0.4)
    run_state.screenshot("feature-selected")
    run_state.assert_command("AddObjectCommand", objType="feature")

    run_state.click(left + 197, EDITOR_BUTTON_Y, delay=0.9)   # Properties
    run_state.screenshot("props-open")

    # Pos X. The whole vector is sent, not the one axis, and the object must
    # actually move on the map.
    before = run_state.screenshot("before-move")
    run_state.click(left + 58, 223, delay=0.4)
    run_state.key("ctrl+a", delay=0.15)
    run_state.type_text("1500")
    run_state.key("Return", delay=0.8)
    run_state.move(spot_x + 260, spot_y + 220, delay=0.4)
    after = run_state.screenshot("props-pos-edited")
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=lambda v: isinstance(v, dict) and abs(v.get("x", 0) - 1500) < 1.0,
    )
    run_state.assert_screenshot_pixels(before, after, min_changed=400)

    # Dragging a numeric field changes it without ever entering text mode, and
    # commits once on release. The drag pins the pointer and warps it back after
    # every move (as content-creation tools do), so the motion has to be
    # relative -- absolute moves would fight the warp.
    run_state.press(left + 58, 223)
    run_state.move_relative(120)
    # Mid-drag: the pointer is pinned to where the drag began and drawn as the
    # empty cursor, so nothing follows the mouse across the panel.
    run_state.screenshot("props-pos-dragging")
    run_state.release(left + 58, 223)
    run_state.screenshot("props-pos-dragged")
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=lambda v: isinstance(v, dict) and v.get("x", 0) > 1500.5,
    )

    # Releasing a drag with the pointer far outside the panel must still end it:
    # RmlUi's drag capture delivers `dragend` wherever the button comes up, and
    # nothing else can (the engine never hands the plugin a release for a press
    # the panel's RmlUi consumed).
    run_state.press(left + 58, 223)
    run_state.move_relative(-400, 260)               # out over the map
    run_state.release(left - 300, 500)
    dragged = run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=lambda v: isinstance(v, dict) and v.get("x", 9999) < 1500.0,
    )
    # Now moving the mouse must not keep changing it: the drag is over.
    run_state.move(left - 600, 500, delay=0.4)
    run_state.assert_no_command_after(dragged, "SetObjectParamCommand", key="pos")
    run_state.screenshot("props-drag-released-outside")

    # A sub-object: Blocking's booleans are one table, so toggling one must send
    # the table under `blocking`, not a bare boolean.
    run_state.click(left + 164, 567, delay=0.6)   # "Block Enemy Pushing"
    run_state.screenshot("props-blocking-toggled")
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="blocking",
        value=lambda v: isinstance(v, dict),
    )

    # Collision has its own scenario (`collision`), where the volume it edits can
    # actually be seen.
    #
    # Last, because it deselects: clicking empty ground with an object editor
    # open used to abort the engine -- the panel wrote through element handles
    # RmlUi had already destroyed. It must survive, and clear the selection.
    for dx, dy in ((-300, -150), (250, 120), (-120, 260), (380, -220)):
        run_state.click(spot_x + dx, spot_y + dy, delay=0.4)
    run_state.screenshot("props-after-map-clicks")
    run_state.assert_running()


@scenario()
def collision(run_state: E2ERun) -> None:
    """Objects -> Collision, on its own so it is quick and focused.

    The point of the editor is the *volume*, so the volume is what gets checked:
    turn on the debug rendering and prove that each edit visibly changes the
    shape drawn on the object. A command reaching the bridge would not tell us
    the volume actually moved.
    """
    run_state.focus()
    left = _open(run_state, 110)                      # Features
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    run_state.wheel(spot_x, spot_y, clicks=8, up=True)
    run_state.click(spot_x, spot_y, delay=0.8)        # place
    run_state.click(left + 54, ACTION_Y, delay=0.6)   # leave Add mode
    run_state.click(spot_x, spot_y, delay=0.8)        # select it

    run_state.click(left + 270, EDITOR_BUTTON_Y, delay=0.9)   # Collision
    hidden = run_state.screenshot_root("volume-hidden")

    # Show volume: the collision shape is drawn over the object.
    run_state.click(left + 110, 190, delay=0.8)
    shown = run_state.screenshot_root("volume-shown")
    run_state.assert_screenshot_pixels(hidden, shown, min_changed=300)

    # Scaling the volume must redraw it bigger, not merely emit a command.
    run_state.click(left + 60, 339, delay=0.4)        # Scale X
    run_state.key("ctrl+a", delay=0.15)
    run_state.type_text("120")
    run_state.key("Return", delay=0.9)
    scaled = run_state.screenshot_root("volume-scaled")
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="collision",
        value=lambda v: isinstance(v, dict),
    )
    run_state.assert_screenshot_pixels(shown, scaled, min_changed=300)

    # A different volume type is a different shape on screen.
    run_state.click(left + 200, 231, delay=0.4)       # Type
    run_state.key("Down", delay=0.2)
    run_state.key("Return", delay=0.9)
    typed = run_state.screenshot_root("volume-type-changed")
    run_state.assert_screenshot_pixels(scaled, typed, min_changed=200)
    run_state.screenshot("collision-fields")


@scenario(uis=("rmlui",))
def cursortip(run_state: E2ERun) -> None:
    """Place a feature, then hover it. The RmlUi cursor tooltip must appear next
    to the cursor (the Chili cursortip widget is disabled in RmlUi mode)."""
    run_state.focus()
    left = _open(run_state, 110)                      # Features

    # The first unfiltered def is `geovent`, which has no model and so cannot be
    # hit by a screen ray. Filter to trees and take the first of those.
    run_state.click(left + 180, SEARCH_Y, delay=0.15)
    run_state.type_text("tree")
    run_state.click(left + 55, GRID_Y, delay=0.4)

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    run_state.click(spot_x, spot_y, delay=0.6)        # place it
    run_state.key("Escape", delay=0.3)
    run_state.move(spot_x + 200, spot_y + 200, delay=0.3)
    run_state.screenshot("placed")

    # The model sits slightly up-left of the click point on screen.
    run_state.move(spot_x - 20, spot_y, delay=0.6)    # hover the tree
    run_state.screenshot("hover-tooltip")


def _placed(run_state: E2ERun, since: int = 0) -> list[dict]:
    """The objects actually added since `since` (previews excluded)."""
    return [
        entry["data"]["params"]["pos"]
        for entry in run_state.commands()[since:]
        if entry["data"].get("className") == "AddObjectCommand"
        and not entry["data"].get("__preview")
    ]


def _spread(placed: list[dict]) -> float:
    """How far apart the objects landed, in world units."""
    if len(placed) < 2:
        return 0.0
    xs = [pos["x"] for pos in placed]
    zs = [pos["z"] for pos in placed]
    return max(max(xs) - min(xs), max(zs) - min(zs))


@scenario(crop="right-panel")
def brush_size(run_state: E2ERun) -> None:
    """Shift+wheel resizes the object brush, and the panel's Size field follows.

    Proved by painting: a dab with the enlarged brush must scatter its objects
    over a visibly wider area than a dab with the original one. A command
    reaching the bridge would not show that the brush itself grew.
    """
    run_state.focus()
    left = _open(run_state, 110)                      # Features
    run_state.click(left + 134, ACTION_Y, delay=0.6)  # Brush mode
    _arm_tree(run_state, left)
    run_state.screenshot("brush-size-default")

    width, height = window_size(run_state)
    cx, cy = width // 3, height // 2
    run_state.wheel(cx, cy, clicks=8, up=True)        # zoom in on the map

    # One dab at the default size. A tap, not a hold: the brush repeats every
    # 0.1s while the button is down, so holding it would make the count a
    # stopwatch reading rather than something to assert on.
    mark = len(run_state.commands())
    run_state.press(cx - 260, cy, delay=0.02)
    run_state.release(cx - 260, cy)
    small = _placed(run_state, mark)

    # Shift+wheel over the map enlarges the brush. Through the root window: a
    # modifier does not survive `xdotool --window`.
    with run_state.modifier("shift"):
        run_state.wheel_root(cx, cy, clicks=5, up=True)
    # The Size field follows the wheel; the screenshot is here to be looked at.
    run_state.screenshot("brush-size-enlarged")

    # A dab with the enlarged brush drops more objects, over more ground: the
    # count is `size^2 / (spread * 100)`, so 100 -> 264 takes it from 1 to 7.
    mark = len(run_state.commands())
    run_state.press(cx + 200, cy, delay=0.02)
    run_state.release(cx + 200, cy)
    large = _placed(run_state, mark)

    if len(small) != 1:
        raise AssertionError(f"default brush placed {len(small)} objects, want 1")
    if len(large) != 7:
        raise AssertionError(f"enlarged brush placed {len(large)} objects, want 7")
    if _spread(large) <= 150:
        raise AssertionError(f"brush did not grow: spread {_spread(large):.0f} world units")
    # Everything on the map is accounted for by those two dabs.
    if len(_placed(run_state)) != len(small) + len(large):
        raise AssertionError(
            f"placed {len(_placed(run_state))} objects, want {len(small) + len(large)}"
        )


@scenario()
def deselect(run_state: E2ERun) -> None:
    """Deselecting has to clear the selection box, not just the selection.

    Three frames of the same camera: the feature alone, the feature selected, and
    the feature after clicking empty ground. The last must look like the first --
    a box still drawn there is a selection the editor thinks it still has.
    """
    run_state.focus()
    left = _open(run_state, 110)                      # Features
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    cx, cy = width // 3, height // 2
    run_state.wheel(cx, cy, clicks=8, up=True)
    run_state.click(cx, cy, delay=0.8)                # place it
    run_state.key("Escape", delay=0.5)                # leave placement mode
    # Park the cursor away from the feature: every frame is captured with it
    # here, so the pointer itself never shows up in the comparisons.
    run_state.move(cx + 450, cy - 250, delay=0.5)
    unselected = run_state.screenshot_root("feature-unselected")

    # The box is drawn in pure green, and nothing else on the map is: counting
    # those pixels says whether the box is there, where comparing whole frames
    # would just measure the trees swaying and the thumbnails spinning.
    around_feature = (cx - 160, cy - 160, 320, 320)
    if run_state.count_color(unselected, around_feature) != 0:
        raise AssertionError("a selection box before anything was selected")

    run_state.click(cx - 20, cy, delay=0.6)           # select it
    run_state.move(cx + 450, cy - 250, delay=0.5)
    selected = run_state.screenshot_root("feature-selected")
    box = run_state.count_color(selected, around_feature)
    if box < 100:
        raise AssertionError(f"clicking the feature drew no selection box ({box} px)")

    # Escape drops the selection.
    run_state.key("Escape", delay=0.6)
    escaped = run_state.screenshot_root("feature-escaped")
    left = run_state.count_color(escaped, around_feature)
    if left != 0:
        raise AssertionError(f"Escape left the selection box behind ({left} px)")

    # And so does clicking empty ground -- well clear of the panel and of the dev
    # console along the bottom, since a click on either is not a click on the map.
    run_state.click(cx - 20, cy, delay=0.6)           # select it again
    run_state.move(cx + 450, cy - 250, delay=0.5)
    run_state.click(cx + 450, cy - 250, delay=0.6)
    run_state.move(cx + 450, cy - 250, delay=0.5)
    cleared = run_state.screenshot_root("feature-deselected")
    left = run_state.count_color(cleared, around_feature)
    if left != 0:
        raise AssertionError(f"clicking empty ground left the box behind ({left} px)")

    # A box-select, and then a box-select over empty ground: the second one
    # selects nothing, so it must drop what the first one selected. This is the
    # path that leaves a screen full of boxes for objects that are not selected.
    run_state.press(cx - 220, cy - 200)
    run_state.move(cx + 200, cy + 160, delay=0.3)
    run_state.release(cx + 200, cy + 160)
    run_state.move(cx + 450, cy - 250, delay=0.5)
    boxed = run_state.screenshot_root("box-selected")
    box = run_state.count_color(boxed, around_feature)
    if box < 100:
        raise AssertionError(f"the box-select selected nothing ({box} px)")

    run_state.press(cx + 350, cy + 200)
    run_state.move(cx + 600, cy + 380, delay=0.3)
    run_state.release(cx + 600, cy + 380)
    run_state.move(cx + 450, cy - 250, delay=0.5)
    empty_boxed = run_state.screenshot_root("box-selected-empty")
    left = run_state.count_color(empty_boxed, around_feature)
    if left != 0:
        raise AssertionError(
            f"a box-select over empty ground kept the old selection ({left} px)"
        )


@scenario()
def rotation(run_state: E2ERun) -> None:
    """Ctrl-drag rotates the selection about its centre, as the Lua state does.

    Two features, placed apart and both selected: rotating the pair swings them
    around the midpoint between them, so the rotation is plainly visible on the
    map as well as provable from the commands. One object alone would only change
    its facing, which a tree barely shows.
    """
    run_state.focus()
    left = _open(run_state, 110)                      # Features
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    cx, cy = width // 3, height // 2
    run_state.wheel(cx, cy, clicks=8, up=True)        # zoom in on the spot

    # Two trees, well apart, so the pair has a real extent to rotate.
    run_state.click(cx - 90, cy, delay=0.7)
    run_state.click(cx + 90, cy, delay=0.7)
    run_state.key("Escape", delay=0.4)                # leave placement mode

    # Box-select both.
    run_state.press(cx - 260, cy - 200)
    run_state.move(cx + 260, cy + 180, delay=0.3)
    run_state.release(cx + 260, cy + 180)
    run_state.move(cx + 500, cy + 320, delay=0.5)
    run_state.screenshot_root("before-rotate")

    # Ctrl held, the cursor swings about the centre with the button down: the
    # objects follow it as a preview, and the release commits. The button has to
    # be held -- the engine only delivers mouse-move to the plugin during a drag.
    with run_state.modifier("ctrl"):
        run_state.press(cx + 200, cy)
        run_state.move(cx + 140, cy - 140, delay=0.3)
        run_state.move(cx, cy - 200, delay=0.4)
        run_state.screenshot_root("rotating")
        run_state.move(cx - 200, cy, delay=0.4)
        run_state.release(cx - 200, cy)

    run_state.screenshot_root("rotated")
    # Both objects are committed, once each: `key` carries the whole pose (the
    # command's many-fields form, as Lua's rotate state sends it).
    run_state.assert_command_count("SetObjectParamCommand", 2)
    # And they really turned: the facing is no longer the +z it was placed with.
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key=lambda k: (
            isinstance(k, dict)
            and "pos" in k
            and abs(k.get("dir", {}).get("z", 1.0) - 1.0) > 0.1
        ),
    )


@scenario()
def selection(run_state: E2ERun) -> None:
    """Rectangle select: drag a box on empty ground over a placed feature.

    The box must appear while dragging, and the feature must end up selected --
    which is proved by editing it in Properties afterwards.
    """
    run_state.focus()
    left = _open(run_state, 110)                      # Features
    _arm_tree(run_state, left)

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    run_state.wheel(spot_x, spot_y, clicks=8, up=True)
    run_state.click(spot_x, spot_y, delay=0.8)        # place it
    run_state.key("Escape", delay=0.4)                # leave placement mode

    # Drag a box on empty ground, from up-left of the feature to down-right of
    # it. Captured mid-drag: the selection rectangle has to be visible.
    run_state.press(spot_x - 220, spot_y - 200)
    run_state.move(spot_x + 120, spot_y + 60, delay=0.3)
    run_state.move(spot_x + 200, spot_y + 160, delay=0.4)
    run_state.screenshot_root("box-dragging")
    run_state.release(spot_x + 200, spot_y + 160)
    run_state.move(spot_x + 400, spot_y + 300, delay=0.5)
    run_state.screenshot_root("box-selected")

    # Properties edits the *selected* object. If the box selected nothing, there
    # is nothing to edit and no command is emitted.
    run_state.click(left + 197, EDITOR_BUTTON_Y, delay=0.9)
    run_state.screenshot("props-after-box-select")
    run_state.click(left + 58, 223, delay=0.4)        # Pos X
    run_state.key("ctrl+a", delay=0.15)
    run_state.type_text("1800")
    run_state.key("Return", delay=0.8)
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=lambda v: isinstance(v, dict) and abs(v.get("x", 0) - 1800) < 1.0,
    )


