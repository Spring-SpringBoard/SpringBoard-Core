"""The Dev tab's control gallery: every field type, at rest and under input.

A kitchen sink. One scenario covers the whole control set, so the cross-cutting
behaviours (a numeric committing, a drag, a choice opening, a picker modal) are
tested once, here, rather than incidentally inside whichever editor happens to
use them.

The gallery lives behind `SBC_DEV_PANEL`, so it neither ships in the tab bar nor
appears in any other scenario's screenshots.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import EDITOR_BUTTON_Y, TAB_Y, panel_left
from scenarios.registry import scenario

if TYPE_CHECKING:
    from runner import E2ERun

DEV_PANEL = {"SBC_DEV_PANEL": "1"}

# The Dev tab is appended after Misc (at 300), one tab-width further right.
DEV_TAB_X = 376

# Rows in the Fields gallery, measured off the at-rest golden. The x matters as
# much as the y: a numeric's box is narrow (it ends around x=170) while a string's
# runs to x=345, so one shared click column would miss half the controls.
STRING_Y = 222
NUMBER_Y = 331
BOUNDED_Y = 374
BOOL_ON_Y = 475
CHOICE_Y = 583
COLOUR_Y = 650

WIDE_X = 200      # string, choice: their boxes reach this far
NARROW_X = 80     # numeric: its box does not
CHECK_X = 142     # the boolean's checkbox
SWATCH_X = 149    # the colour swatch


def _values(run_state: E2ERun) -> dict[str, str]:
    """What each control reported, from the gallery's own log lines."""
    values: dict[str, str] = {}
    for line in run_state.engine_log():
        _, _, tail = line.partition("dev-fields: ")
        if not tail or " = " not in tail:
            continue
        name, _, value = tail.strip().partition(" = ")
        # A dragged value is tagged, since a drag never fires a DOM change.
        values[name] = value.removesuffix(" (dragged)").strip()
    return values


@scenario(crop="right-panel", env=DEV_PANEL)
def gallery(run_state: E2ERun) -> None:
    """Every control at rest, then every control driven."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + DEV_TAB_X, TAB_Y, delay=0.4)
    run_state.click(left + 40, EDITOR_BUTTON_Y, delay=0.8)

    # At rest: this one image is the whole control set -- string, numeric (plain,
    # bounded, 3-decimal), boolean on and off, choice, colour, asset, and a group
    # laid out on one row.
    run_state.golden("fields-at-rest")

    # String: click, select all, type, commit.
    run_state.click(left + WIDE_X, STRING_Y, delay=0.3)
    run_state.key("ctrl+a", delay=0.1)
    run_state.type_text("typed")
    run_state.key("Return", delay=0.4)

    # Numeric: typed.
    run_state.click(left + NARROW_X, NUMBER_Y, delay=0.3)
    run_state.key("ctrl+a", delay=0.1)
    run_state.type_text("7.5")
    run_state.key("Return", delay=0.4)

    # Numeric: dragged. The pointer is pinned and warped back, so the motion has
    # to be relative.
    run_state.press(left + NARROW_X, BOUNDED_Y)
    run_state.move_relative(90)
    dragging = run_state.golden("numeric-dragging", park=False)
    run_state.release(left + NARROW_X, BOUNDED_Y)

    # Boolean: toggled.
    run_state.click(left + CHECK_X, BOOL_ON_Y, delay=0.4)

    # Choice: opened and a different item picked.
    run_state.click(left + WIDE_X, CHOICE_Y, delay=0.3)
    run_state.golden("choice-open", park=False)
    run_state.key("Down", delay=0.2)
    run_state.key("Return", delay=0.5)

    run_state.golden("fields-after-input")

    values = _values(run_state)
    expected = {
        "text": '"typed"',
        "number": "7.5",
        "flag_on": "false",
        "choice": '"Second"',
    }
    for name, want in expected.items():
        got = values.get(name)
        if got != want:
            raise AssertionError(
                f"{name}: control reported {got!r}, expected {want!r}"
                f"\nall values: {values}"
            )
    # The drag moved the bounded field off its default without typing into it.
    bounded = float(values.get("bounded", "50"))
    if bounded <= 50.0:
        raise AssertionError(f"dragging the numeric did not raise it: {bounded}")
    _ = dragging


@scenario(crop="right-panel", env=DEV_PANEL)
def gallery_pickers(run_state: E2ERun) -> None:
    """The two modal pickers a field can open: colour and asset."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + DEV_TAB_X, TAB_Y, delay=0.4)
    run_state.click(left + 40, EDITOR_BUTTON_Y, delay=0.8)

    # The colour field opens the picker. Captured full-frame: the modal is drawn
    # beside the panel, outside the crop the rest of this case uses.
    run_state.click(left + SWATCH_X, COLOUR_Y, delay=0.8)
    run_state.golden("colour-picker", crop=None)
    run_state.key("Escape", delay=0.5)
    run_state.golden("colour-picker-closed")
