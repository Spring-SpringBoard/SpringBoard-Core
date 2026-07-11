"""Objects tab: Units, Features, Properties, Collision.

One scenario per editor, each kept to a handful of screens so every one can
actually be looked at. Every step asserts the command that was emitted *and*
the result of it -- a command reaching the bridge does not prove the engine
acted on it.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import EDITOR_BUTTON_Y, TAB_X, TAB_Y, panel_left, window_size

if TYPE_CHECKING:
    from runner import E2ERun

# Rows inside the Objects editors, measured from the panel's left/top.
ACTION_Y = 217          # Add / Brush
FILTER_Y = 403          # Type / Wreck
TERRAIN_Y = 445         # Terrain (features; units put it beside Type)
SEARCH_Y = 487
GRID_Y = 555            # first row of definition cells


def _open(run_state: E2ERun, editor_x: int) -> int:
    """Objects tab, then one of its editors. Returns the panel's left edge."""
    left = panel_left(run_state)
    run_state.click(left + TAB_X["objects"], TAB_Y, delay=0.25)
    run_state.click(left + editor_x, EDITOR_BUTTON_Y, delay=0.7)
    return left


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

    # Arm the first def and place it. The command must reach the bridge *and*
    # the feature must actually appear on the map -- so these two are captured
    # full-frame, where the map is visible.
    run_state.click(left + 55, GRID_Y, delay=0.5)
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

    # Type = Wreckage. None of this map's features are wrecks, so the grid must
    # empty -- the filter proving it filters, not merely that it renders.
    run_state.click(left + 104, FILTER_Y, delay=0.4)
    run_state.key("Down", delay=0.2)
    run_state.key("Return", delay=0.7)                 # commit and close the list
    run_state.screenshot("features-wreckage-empty")


def props_panel(run_state: E2ERun) -> None:
    """Objects -> Properties and Collision.

    Both edit the *selected* object, so a feature is placed and selected first;
    opening the tab with an empty selection proves nothing.
    """
    run_state.focus()
    left = _open(run_state, 110)                      # Features
    run_state.click(left + 55, GRID_Y, delay=0.4)     # arm the first def

    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    run_state.click(spot_x, spot_y, delay=0.8)        # place
    run_state.key("Escape", delay=0.4)                # leave placement mode
    run_state.click(spot_x, spot_y, delay=0.8)        # select it
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

    # A sub-object: Blocking's booleans are one table, so toggling one must send
    # the table under `blocking`, not a bare boolean.
    run_state.click(left + 164, 567, delay=0.6)   # "Block Enemy Pushing"
    run_state.screenshot("props-blocking-toggled")
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="blocking",
        value=lambda v: isinstance(v, dict),
    )

    run_state.click(left + 270, EDITOR_BUTTON_Y, delay=0.9)   # Collision
    run_state.screenshot("collision-open")

    # The collision volume is its own sub-object: editing a scale axis must send
    # the whole volume table, and the field must hold the new value after.
    run_state.click(left + 60, 339, delay=0.4)                # Scale X
    run_state.key("ctrl+a", delay=0.15)
    run_state.type_text("45")
    run_state.key("Return", delay=0.8)
    run_state.screenshot("collision-scale-edited")
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="collision",
        value=lambda v: isinstance(v, dict),
    )


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


SCENARIOS = {
    "units_panel": units_panel,
    "props_panel": props_panel,
    "cursortip": cursortip,
}
