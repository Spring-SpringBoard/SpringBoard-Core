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

from scenarios.geometry import EDITOR_BUTTON_Y, TAB_Y, panel_left, window_size
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

ASSET_Y = 692

WIDE_X = 200      # string, choice: their boxes reach this far
NARROW_X = 80     # numeric: its box does not
CHECK_X = 142     # the boolean's checkbox
SWATCH_X = 149    # the colour swatch
ASSET_X = 60      # the asset button

# The toolbar strip above the editor: New Project first, then Load.
TOOLBAR_Y = 150
TOOLBAR_X = 22
TOOLBAR_STEP = 35

# The tooltip's background (`.native-tooltip`), near-black and nothing else is.
TOOLTIP_COLOR = "#0b0d0c"

# The modals, in window coordinates, measured off their goldens. They open up and
# left of centre, not on it.
COLOUR_SQUARE = (900, 350)   # inside the saturation/value gradient
COLOUR_OK = (1140, 473)

ASSET_FILE_CELL = (993, 333)   # grass3.jpg, the third cell
ASSET_OK = (1137, 602)


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


def _open_gallery(run_state: E2ERun) -> int:
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + DEV_TAB_X, TAB_Y, delay=0.4)
    run_state.click(left + 40, EDITOR_BUTTON_Y, delay=0.8)
    return left


@scenario(crop="right-panel", env=DEV_PANEL)
def gallery_pickers(run_state: E2ERun) -> None:
    """The two modal pickers a field can open: colour and asset.

    Each is driven to a *committed value*, not merely opened: the field reports
    what it holds afterwards, and that is what is asserted.
    """
    left = _open_gallery(run_state)

    # Colour. Captured full-frame: the modal is drawn beside the panel, outside
    # the crop the rest of this case uses.
    run_state.click(left + SWATCH_X, COLOUR_Y, delay=0.8)
    run_state.golden("colour-picker", crop=None)

    # Pick from the gradient, then OK. Measured off the golden -- the modal sits
    # up and left of centre, not on it.
    #
    # The square is *grabbed*, not clicked: mousedown starts the grab and the
    # colour follows the pointer on each tick, so a press-and-release with no time
    # between them is over before a single tick has run.
    run_state.press(*COLOUR_SQUARE)
    run_state.move(COLOUR_SQUARE[0] + 8, COLOUR_SQUARE[1] + 8, delay=0.4)
    run_state.release(COLOUR_SQUARE[0] + 8, COLOUR_SQUARE[1] + 8)
    run_state.golden("colour-picked", crop=None)
    run_state.click(*COLOUR_OK, delay=0.6)
    run_state.golden("colour-committed")

    colour = _values(run_state).get("colour")
    if colour is None or colour == "[1.0, 1.0, 1.0, 1.0]":
        raise AssertionError(f"the picker committed no new colour (got {colour})")

    # Asset: browse the grid, pick a file, OK. The picker's *folder* navigation is
    # shown by the file dialog (`gallery_dialogs`) -- the same GridView drives
    # both, and this root is flat.
    run_state.click(left + ASSET_X, ASSET_Y, delay=1.0)
    run_state.golden("asset-picker", crop=None)

    run_state.click(*ASSET_FILE_CELL, delay=0.6)       # a file in the grid
    run_state.golden("asset-selected", crop=None)
    run_state.click(*ASSET_OK, delay=0.8)
    run_state.golden("asset-committed")

    asset = _values(run_state).get("asset", "").strip('"')
    if not asset:
        raise AssertionError("picking an asset committed nothing")
    if not asset.lower().endswith((".png", ".jpg")):
        raise AssertionError(f"the asset field committed {asset!r}, not a file path")


@scenario(crop="right-panel", env={**DEV_PANEL, "SBC_HIDE_TOOLTIPS": "0"})
def gallery_tooltips(run_state: E2ERun) -> None:
    """Hovering a control shows its tooltip.

    Tooltips are off in every other scenario -- they follow the cursor and would
    land in the middle of whatever is being captured -- so this is the one place
    they are proved to exist at all.
    """
    left = _open_gallery(run_state)

    # Away from any control: nothing.
    run_state.move(left + 400, 900, delay=0.5)
    empty = run_state.golden("no-tooltip", park=False)

    # Over the numeric: its tooltip appears next to the cursor. Asserted by diff,
    # not by colour: the tooltip is near-black, and so is half the panel. In the
    # *captured* image's coordinates -- these shots are cropped to the panel, so
    # they start at 0, not at the panel's position on screen.
    run_state.move(left + NARROW_X, NUMBER_Y, delay=0.8)
    hovered = run_state.golden("numeric-tooltip", park=False)
    box = (20, 200, 460, 400)
    run_state.assert_region_pixels(empty, hovered, box, min_changed=800)

    # And it goes away again.
    run_state.move(left + 400, 900, delay=0.8)
    gone = run_state.golden("tooltip-gone", park=False)
    run_state.assert_region_pixels(empty, gone, box, max_changed=200)


@scenario(env=DEV_PANEL)
def gallery_dialogs(run_state: E2ERun) -> None:
    """The two dialogs the toolbar opens: New Project, and the file dialog.

    Full-frame: both are centred on the screen, not inside the panel.
    """
    left = _open_gallery(run_state)

    # New Project (the first toolbar icon).
    run_state.click(left + TOOLBAR_X, TOOLBAR_Y, delay=1.0)
    run_state.golden("new-project")
    run_state.key("Escape", delay=0.6)
    run_state.golden("new-project-closed")

    # Load (the second): the file dialog, with its path navigation and grid. It
    # opens on the projects dir, which is empty in an isolated boot -- so folder
    # navigation is shown by going *up* from it, into a directory that has some.
    # This is the same GridView the asset picker browses with.
    run_state.click(left + TOOLBAR_X + TOOLBAR_STEP, TOOLBAR_Y, delay=1.0)
    run_state.golden("file-dialog")

    run_state.click(*FILE_UP, delay=0.9)
    up = run_state.golden("file-dialog-up")
    run_state.click(*FILE_FIRST_CELL, delay=0.9)
    into = run_state.golden("file-dialog-in-folder")
    # Navigating changed the listing: a grid that never redrew is a grid that
    # never navigated.
    run_state.assert_screenshot_pixels(up, into, min_changed=500)

    run_state.key("Escape", delay=0.6)
    run_state.golden("file-dialog-closed")
