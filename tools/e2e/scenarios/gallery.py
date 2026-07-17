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

# Frames captured with `park=False` have the pointer in shot, and the engine's
# cursor does not render bit-identically between runs (~60px of difference). The
# panel behind it does, so the budget stays far below any real UI change.
CURSOR_IN_SHOT = 200

# A shot showing the dragged numeric: its digits vary run to run (see below).
DRAGGED_DIGIT = 200

# The Dev tab is appended after Misc (at 300), one tab-width further right.
DEV_TAB_X = 376

# Rows in the Fields gallery, measured off the at-rest golden. The x matters as
# much as the y: a numeric's box is narrow (it ends around x=170) while a string's
# runs to x=345, so one shared click column would miss half the controls.
STRING_Y = 222
EMPTY_Y = 264
NUMBER_Y = 331
BOUNDED_Y = 374
PRECISE_Y = 417
BOOL_ON_Y = 475
BOOL_OFF_Y = 515
CHOICE_Y = 583
COLOUR_Y = 650

ASSET_Y = 692

# Compact X/Y/Z controls deliberately share one row at panel width.
GROUP_XYZ_Y = 760
GROUP_SECOND_X = 220
GROUP_THIRD_X = 385

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

ASSET_FIRST_CELL = (842, 333)  # the first cell of the picker's grid
ASSET_UP = (830, 267)          # the "Up" button
ASSET_OK = (1137, 602)

# The file dialog: same layout, its own modal. It opens on the projects dir, which
# is empty in an isolated boot, so navigation is shown by going *up* out of it.
FILE_UP = (828, 267)
FILE_FIRST_CELL = (847, 333)


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
    dragging = run_state.golden("numeric-dragging", park=False, tolerance=CURSOR_IN_SHOT)
    run_state.release(left + NARROW_X, BOUNDED_Y)

    # Boolean: toggled.
    run_state.click(left + CHECK_X, BOOL_ON_Y, delay=0.4)

    # Choice: opened and a different item picked.
    run_state.click(left + WIDE_X, CHOICE_Y, delay=0.3)
    run_state.golden("choice-open", park=False, tolerance=CURSOR_IN_SHOT)
    run_state.key("Down", delay=0.2)
    run_state.key("Return", delay=0.5)

    # The dragged field's value lands a digit or two either side of the same
    # number between runs (the drag ends on whichever tick the release meets), so
    # the glyphs in that one box differ. Its *value* is asserted below.
    run_state.golden("fields-after-input", tolerance=DRAGGED_DIGIT)

    # The rest of the control set, driven after the shots above so those keep
    # showing one change at a time.
    #
    # The empty string field takes a value like any other.
    run_state.click(left + WIDE_X, EMPTY_Y, delay=0.3)
    run_state.type_text("filled")
    run_state.key("Return", delay=0.4)

    # A bounded field clamps what is typed into it: 5 is outside -1..1.
    run_state.click(left + NARROW_X, PRECISE_Y, delay=0.3)
    run_state.key("ctrl+a", delay=0.1)
    run_state.type_text("5")
    run_state.key("Return", delay=0.4)

    # The other checkbox, off -> on.
    run_state.click(left + CHECK_X, BOOL_OFF_Y, delay=0.4)

    # A grouped field is a field: the ones sharing a row commit independently.
    for x, y, value in (
        (NARROW_X, GROUP_XYZ_Y, "11"),
        (GROUP_SECOND_X, GROUP_XYZ_Y, "22"),
        (GROUP_THIRD_X, GROUP_XYZ_Y, "33"),
    ):
        run_state.click(left + x, y, delay=0.3)
        run_state.key("ctrl+a", delay=0.1)
        run_state.type_text(value)
        run_state.key("Return", delay=0.4)

    # Still shows the dragged field, so still carries its wandering digits.
    run_state.golden("fields-rest-of-set", tolerance=DRAGGED_DIGIT)

    # Escape reverts an edit instead of committing it: the field keeps the value
    # it had, and the control reports nothing new.
    run_state.click(left + WIDE_X, STRING_Y, delay=0.3)
    run_state.key("ctrl+a", delay=0.1)
    run_state.type_text("discarded")
    run_state.key("Escape", delay=0.4)
    run_state.golden("string-escape-reverted")

    values = _values(run_state)
    expected = {
        "text": '"typed"',
        "empty": '"filled"',
        "number": "7.5",
        "flag_on": "false",
        "flag_off": "true",
        "choice": '"Second"',
        "vec_x": "11",
        "vec_y": "22",
        "vec_z": "33",
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
    if bounded > 100.0:
        raise AssertionError(f"the drag pushed the field past its max: {bounded}")

    # 5 typed into a -1..1 field is held at the bound, not taken literally.
    precise = float(values.get("precise", "0.125"))
    if precise != 1.0:
        raise AssertionError(f"typing 5 into a -1..1 field gave {precise}, not its max 1.0")
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

    # Asset. The picker opens on the **asset packs**, not on a directory: the
    # field's root (`brush_textures/`) is a place *inside* a pack. So the first
    # screen lists `core/`, and going into it lists that pack's brush textures.
    run_state.click(left + ASSET_X, ASSET_Y, delay=1.0)
    packs = run_state.golden("asset-packs", crop=None)

    run_state.click(*ASSET_FIRST_CELL, delay=0.9)      # into the `core` pack
    inside = run_state.golden("asset-in-pack", crop=None)
    # Navigating changed the listing: a grid that never redrew never navigated.
    run_state.assert_screenshot_pixels(packs, inside, min_changed=500)

    run_state.click(*ASSET_UP, delay=0.9)              # and back out to the packs
    back = run_state.golden("asset-back-at-packs", crop=None)
    run_state.assert_screenshot_pixels(inside, back, min_changed=500)

    # In again, pick a texture, OK.
    run_state.click(*ASSET_FIRST_CELL, delay=0.9)
    run_state.click(*ASSET_FIRST_CELL, delay=0.6)      # the first texture
    run_state.golden("asset-selected", crop=None)
    run_state.click(*ASSET_OK, delay=0.8)
    run_state.golden("asset-committed")

    # An *asset path* -- `core/...` -- which is what a project stores, not a
    # filesystem path.
    asset = _values(run_state).get("asset", "").strip('"')
    if not asset.startswith("core/"):
        raise AssertionError(f"the asset field committed {asset!r}, not an asset path")
    if not asset.lower().endswith((".png", ".jpg")):
        raise AssertionError(f"the asset field committed {asset!r}, not a file")


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

    # Up at the root does nothing: the dialog never browses above the directory it
    # was opened on. (Navigating *into* a folder is driven by the asset picker,
    # which has one; the projects dir is empty in an isolated boot.)
    opened = run_state.golden("file-dialog-open")
    run_state.click(*FILE_UP, delay=0.9)
    up = run_state.golden("file-dialog-up")
    # The status strip is live telemetry, so compare the dialog it is meant to
    # keep unchanged rather than every changing CPU/RAM glyph at screen bottom.
    run_state.assert_region_pixels(opened, up, (790, 200, 485, 430), max_changed=200)

    run_state.key("Escape", delay=0.6)
    run_state.golden("file-dialog-closed")
