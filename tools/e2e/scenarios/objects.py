"""Objects tab: Units, Features, Properties, Collision, and the cursor tooltip."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import EDITOR_BUTTON_Y, TAB_X, TAB_Y, panel_left, window_size

if TYPE_CHECKING:
    from runner import E2ERun


def units_panel(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    # Objects tab is the default tab; click it to be safe.
    run_state.click(left + TAB_X["objects"], TAB_Y, delay=0.2)
    run_state.screenshot("objects-tab")
    # First toolbox button is Units (order 0).
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.4)
    run_state.screenshot("units-open")
    # Second toolbox button is Features.
    run_state.click(left + 110, EDITOR_BUTTON_Y, delay=0.4)
    run_state.screenshot("features-open")
    # Click several grid items in sequence to exercise selection -> state
    # rebuild repeatedly (this is where use-after-free crashes show up).
    for col in (55, 140, 225, 310, 55, 140):
        run_state.click(left + col, 555, delay=0.25)
    run_state.screenshot("features-item-click")
    # Type in the search box to exercise filtering (and the old search crash).
    run_state.click(left + 180, 487, delay=0.15)
    run_state.type_text("tree")
    run_state.screenshot("features-search")


def props_panel(run_state: E2ERun) -> None:
    """Objects -> Properties, and Collision.

    Both edit the *selected* object, so the scenario first places a feature and
    selects it -- opening the tab with an empty selection proves nothing.
    """
    run_state.focus()
    left = panel_left(run_state)
    _width, height = window_size(run_state)
    # A patch of map well clear of the panel.
    map_x, map_y = left // 2, height // 2

    run_state.click(left + TAB_X["objects"], TAB_Y, delay=0.2)
    run_state.click(left + 110, EDITOR_BUTTON_Y, delay=0.5)   # Features
    run_state.click(left + 55, 555, delay=0.4)                # first def cell
    run_state.screenshot("feature-armed")

    # Place it, then leave placement mode so the next click selects the feature
    # rather than placing a second one on top of it.
    run_state.click(map_x, map_y, delay=0.7)
    run_state.screenshot("feature-placed")
    run_state.key("Escape", delay=0.4)
    run_state.click(map_x, map_y, delay=0.7)
    run_state.screenshot("feature-selected")

    run_state.click(left + 197, EDITOR_BUTTON_Y, delay=0.8)   # Properties
    run_state.screenshot("props-open")

    run_state.click(left + 270, EDITOR_BUTTON_Y, delay=0.8)   # Collision
    run_state.screenshot("collision-open")


def cursortip(run_state: E2ERun) -> None:
    """Place a feature, then hover it. The RmlUi cursor tooltip must appear next
    to the cursor (the Chili cursortip widget is disabled in RmlUi mode)."""
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)

    run_state.click(left + TAB_X["objects"], TAB_Y, delay=0.2)
    run_state.click(left + 110, EDITOR_BUTTON_Y, delay=0.5)   # Features

    # The first unfiltered def is `geovent`, which has no model and so cannot be
    # hit by a screen ray. Filter to trees and take the first of those.
    run_state.click(left + 180, 487, delay=0.15)
    run_state.type_text("tree")
    run_state.click(left + 55, 555, delay=0.4)

    spot_x, spot_y = width // 3, height // 2
    run_state.click(spot_x, spot_y, delay=0.6)               # place it
    run_state.move(spot_x + 200, spot_y + 200, delay=0.3)
    run_state.screenshot("placed")

    # The model sits slightly up-left of the click point on screen; probe a few
    # offsets so the ray lands on the trunk.
    run_state.move(spot_x - 20, spot_y, delay=0.6)           # hover the tree
    run_state.screenshot("hover-tooltip")


SCENARIOS = {
    "units_panel": units_panel,
    "props_panel": props_panel,
    "cursortip": cursortip,
}
