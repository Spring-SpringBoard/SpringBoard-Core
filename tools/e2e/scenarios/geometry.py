"""Where things are on screen.

Every scenario measures from the same two landmarks, so a layout change is fixed
in one place rather than in twenty magic numbers.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from x11 import window_geometry

if TYPE_CHECKING:
    from runner import E2ERun

# The editor panel is pinned to the right at this width; modals are 480dp wide,
# centred in the area left of it.
PANEL_WIDTH = 500

# Rows inside the panel, from its top.
TAB_Y = 35
EDITOR_BUTTON_Y = 88
ACTION_Y = 217

# Tab centres, as offsets from the panel's left edge.
TAB_X = {"objects": 42, "map": 110, "env": 180, "misc": 300}


def panel_left(run_state: E2ERun) -> int:
    assert run_state.window is not None
    width, _height = window_geometry(run_state.window)
    return width - PANEL_WIDTH


def dialog_left(run_state: E2ERun) -> int:
    assert run_state.window is not None
    width, _height = window_geometry(run_state.window)
    return width // 2 - 490


def window_size(run_state: E2ERun) -> tuple[int, int]:
    assert run_state.window is not None
    return window_geometry(run_state.window)


def editor_button_x(index: int) -> int:
    """The nth editor button in the open tab, as an offset from the panel."""
    return 38 + 72 * index
