"""The Dev tab's control gallery: every field type, at rest and under input.

A kitchen sink. One scenario covers the whole control set, so the cross-cutting
behaviours (a numeric committing, a drag, a choice opening, a picker modal) are
tested once, here, rather than incidentally inside whichever editor happens to
use them.

The gallery lives behind `SBC_DEV_PANEL`, so it neither ships in the tab bar nor
appears in any other scenario's screenshots.
"""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay

from .helpers.geometry import (
    DIALOG,
    GALLERY,
    TAB_Y,
    TOOLBAR,
    dialog_left,
    dialog_point,
    dropdown_option,
    editor_point,
    panel_left,
    panel_point,
)
from .helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState

DEV_PANEL = {"SBC_DEV_PANEL": "1"}

# Frames captured with `park=False` have the pointer in shot, and the engine's
# cursor does not render bit-identically between runs (~60px of difference). The
# panel behind it does, so the budget stays far below any real UI change.
CURSOR_IN_SHOT = 200

# A shot showing the dragged numeric: its digits vary run to run (see below).
DRAGGED_DIGIT = 200

# The tooltip's background (`.native-tooltip`), near-black and nothing else is.
TOOLTIP_COLOR = "#0b0d0c"


@scenario(crop="right-panel", env=DEV_PANEL)
def gallery(run_state: "RunState") -> None:
    """Every control at rest, then every control driven."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + GALLERY["dev_tab_x"], TAB_Y, delay=Delay.MS_400)
    run_state.click(*editor_point(left, "dev", "gallery"), delay=Delay.MS_800)

    # At rest: this one image is the whole control set -- string, numeric (plain,
    # bounded, 3-decimal), boolean on and off, choice, colour, asset, and a group
    # laid out on one row.
    run_state.golden("fields-at-rest")

    # String: click, select all, type, commit.
    run_state.fill_text(
        *panel_point(left, GALLERY["string"]),
        "typed",
        click_delay=Delay.MS_300,
        commit_delay=Delay.MS_400,
    )

    # Numeric: typed.
    run_state.fill_text(
        *panel_point(left, GALLERY["number"]),
        "7.5",
        click_delay=Delay.MS_300,
        commit_delay=Delay.MS_400,
    )

    # Numeric: dragged. The pointer is pinned and warped back, so the motion has
    # to be relative.
    run_state.press(*panel_point(left, GALLERY["bounded"]))
    run_state.move_relative(90)
    dragging = run_state.golden("numeric-dragging", park=False, tolerance=CURSOR_IN_SHOT)
    run_state.release(*panel_point(left, GALLERY["bounded"]))

    # Boolean: toggled.
    run_state.click(*panel_point(left, GALLERY["bool_on"]), delay=Delay.MS_400)

    # Choice: opened and a different item picked.
    run_state.click(*panel_point(left, GALLERY["choice"]), delay=Delay.MS_300)
    run_state.golden("choice-open", park=False, tolerance=CURSOR_IN_SHOT)
    run_state.click(*panel_point(left, dropdown_option(GALLERY["choice"], 1)), delay=Delay.MS_500)

    # The dragged field's value lands a digit or two either side of the same
    # number between runs (the drag ends on whichever tick the release meets), so
    # the glyphs in that one box differ. Its *value* is asserted below.
    run_state.golden("fields-after-input", tolerance=DRAGGED_DIGIT)

    # The rest of the control set, driven after the shots above so those keep
    # showing one change at a time.
    #
    # The empty string field takes a value like any other.
    run_state.click(*panel_point(left, GALLERY["empty"]), delay=Delay.MS_300)
    run_state.type_text("filled")
    run_state.key("Return", delay=Delay.MS_400)

    # A bounded field clamps what is typed into it: 5 is outside -1..1.
    run_state.fill_text(
        *panel_point(left, GALLERY["precise"]),
        "5",
        click_delay=Delay.MS_300,
        commit_delay=Delay.MS_400,
    )

    # The other checkbox, off -> on.
    run_state.click(*panel_point(left, GALLERY["bool_off"]), delay=Delay.MS_400)

    # A grouped field is a field: the ones sharing a row commit independently.
    for point, value in (
        ((GALLERY["number"][0], GALLERY["group_xyz_y"]), "11"),
        ((GALLERY["group_second_x"], GALLERY["group_xyz_y"]), "22"),
        ((GALLERY["group_third_x"], GALLERY["group_xyz_y"]), "33"),
    ):
        run_state.fill_text(*panel_point(left, point), value, click_delay=Delay.MS_300, commit_delay=Delay.MS_400)

    # Still shows the dragged field, so still carries its wandering digits.
    run_state.golden("fields-rest-of-set", tolerance=DRAGGED_DIGIT)

    # Escape reverts an edit instead of committing it: the field keeps the value
    # it had, and the control reports nothing new.
    run_state.click(*panel_point(left, GALLERY["string"]), delay=Delay.MS_300)
    run_state.key("ctrl+a", delay=Delay.MS_100)
    run_state.type_text("discarded")
    run_state.key("Escape", delay=Delay.MS_400)
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
            raise AssertionError(f"{name}: control reported {got!r}, expected {want!r}\nall values: {values}")
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


@scenario(crop="right-panel", env=DEV_PANEL)
def gallery_pickers(run_state: "RunState") -> None:
    """The two modal pickers a field can open: colour and asset.

    Each is driven to a *committed value*, not merely opened: the field reports
    what it holds afterwards, and that is what is asserted.
    """
    left = _open_gallery(run_state)

    # Colour. Captured full-frame: the modal is drawn beside the panel, outside
    # the crop the rest of this case uses.
    run_state.click(*panel_point(left, GALLERY["color"]), delay=Delay.MS_800)
    run_state.golden("colour-picker", crop=None)

    # Pick from the gradient, then OK. Measured off the golden -- the modal sits
    # up and left of centre, not on it.
    #
    # The square is *grabbed*, not clicked: mousedown starts the grab and the
    # colour follows the pointer on each tick, so a press-and-release with no time
    # between them is over before a single tick has run.
    color_square = dialog_point(run_state, DIALOG["color_sample"])
    run_state.press(*color_square)
    run_state.move(color_square[0] + 8, color_square[1] + 8, delay=Delay.MS_400)
    run_state.release(color_square[0] + 8, color_square[1] + 8)
    run_state.golden("colour-picked", crop=None)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok"]), delay=Delay.MS_600)
    run_state.golden("colour-committed")

    colour = _values(run_state).get("colour")
    if colour is None or colour == "[1.0, 1.0, 1.0, 1.0]":
        raise AssertionError(f"the picker committed no new colour (got {colour})")

    # Asset. The picker opens on the **asset packs**, not on a directory: the
    # field's root (`brush_textures/`) is a place *inside* a pack. So the first
    # screen lists `core/`, and going into it lists that pack's brush textures.
    run_state.click(*panel_point(left, GALLERY["asset"]), delay=Delay.S_1)
    packs = run_state.golden("asset-packs", crop=None)

    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell_gallery"]), delay=Delay.MS_900)
    inside = run_state.golden("asset-in-pack", crop=None)
    # Navigating changed the listing: a grid that never redrew never navigated.
    run_state.assert_screenshot_pixels(packs, inside, min_changed=500)

    run_state.click(*dialog_point(run_state, DIALOG["asset_up"]), delay=Delay.MS_900)
    back = run_state.golden("asset-back-at-packs", crop=None)
    run_state.assert_screenshot_pixels(inside, back, min_changed=500)

    # In again, pick a texture, OK.
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell_gallery"]), delay=Delay.MS_900)
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell_gallery"]), delay=Delay.MS_600)
    run_state.golden("asset-selected", crop=None)
    run_state.click(*dialog_point(run_state, DIALOG["asset_ok_gallery"]), delay=Delay.MS_800)
    run_state.golden("asset-committed")

    # An *asset path* -- `core/...` -- which is what a project stores, not a
    # filesystem path.
    asset = _values(run_state).get("asset", "").strip('"')
    if not asset.startswith("core/"):
        raise AssertionError(f"the asset field committed {asset!r}, not an asset path")
    if not asset.lower().endswith((".png", ".jpg")):
        raise AssertionError(f"the asset field committed {asset!r}, not a file")


@scenario(crop="right-panel", env={**DEV_PANEL, "SBC_HIDE_TOOLTIPS": "0"})
def gallery_tooltips(run_state: "RunState") -> None:
    """Hovering a control shows its tooltip.

    Tooltips are off in every other scenario -- they follow the cursor and would
    land in the middle of whatever is being captured -- so this is the one place
    they are proved to exist at all.
    """
    left = _open_gallery(run_state)

    # Away from any control: nothing.
    run_state.move(*panel_point(left, GALLERY["tooltip_parking"]), delay=Delay.MS_500)
    empty = run_state.golden("no-tooltip", park=False)

    # Over the numeric: its tooltip appears next to the cursor. Asserted by diff,
    # not by colour: the tooltip is near-black, and so is half the panel. In the
    # *captured* image's coordinates -- these shots are cropped to the panel, so
    # they start at 0, not at the panel's position on screen.
    run_state.move(*panel_point(left, GALLERY["number"]), delay=Delay.MS_800)
    hovered = run_state.golden("numeric-tooltip", park=False)
    box = (20, 200, 460, 400)
    run_state.assert_region_pixels(empty, hovered, box, min_changed=800)

    # And it goes away again.
    run_state.move(*panel_point(left, GALLERY["tooltip_parking"]), delay=Delay.MS_800)
    gone = run_state.golden("tooltip-gone", park=False)
    run_state.assert_region_pixels(empty, gone, box, max_changed=200)


@scenario(crop="without-status", env=DEV_PANEL)
def gallery_dialogs(run_state: "RunState") -> None:
    """The two dialogs the toolbar opens: New Project, and the file dialog.

    Full-frame: both are centred on the screen, not inside the panel.
    """
    left = _open_gallery(run_state)

    # New Project (the first toolbar icon).
    run_state.click(*panel_point(left, TOOLBAR["new_project"]), delay=Delay.S_1)
    original = run_state.golden("new-project")
    run_state.click(*dialog_point(run_state, DIALOG["new_project_name"]), delay=Delay.MS_200)
    run_state.type_text("E2E project")
    run_state.key("Return", delay=Delay.MS_300)
    for field, value in (("new_project_size_x", "12"), ("new_project_size_y", "14")):
        run_state.fill_text(
            *dialog_point(run_state, DIALOG[field]),
            value,
            click_delay=Delay.MS_200,
            commit_delay=Delay.MS_250,
        )
    edited = run_state.golden("new-project-edited")
    run_state.assert_region_pixels(original, edited, (dialog_left(run_state), 245, 480, 125), min_changed=100)
    run_state.key("Escape", delay=Delay.MS_600)
    run_state.golden("new-project-closed")

    # Load (the second): the file dialog, with its path navigation and grid. It
    # opens on the projects dir, which is empty in an isolated boot -- so folder
    # navigation is shown by going *up* from it, into a directory that has some.
    # This is the same GridView the asset picker browses with.
    run_state.click(*panel_point(left, TOOLBAR["load"]), delay=Delay.S_1)
    run_state.golden("file-dialog")

    # Up at the root does nothing: the dialog never browses above the directory it
    # was opened on. (Navigating *into* a folder is driven by the asset picker,
    # which has one; the projects dir is empty in an isolated boot.)
    opened = run_state.golden("file-dialog-open")
    run_state.click(*dialog_point(run_state, DIALOG["file_up"]), delay=Delay.MS_900)
    up = run_state.golden("file-dialog-up")
    # The status strip is live telemetry, so compare the dialog it is meant to
    # keep unchanged rather than every changing CPU/RAM glyph at screen bottom.
    run_state.assert_region_pixels(opened, up, (790, 200, 485, 430), max_changed=200)

    run_state.key("Escape", delay=Delay.MS_600)
    run_state.golden("file-dialog-closed")

    # A blank project cannot export.
    run_state.click(*panel_point(left, TOOLBAR["export"]), delay=Delay.MS_800)
    run_state.screenshot("export-requires-save")


@scenario(env=DEV_PANEL)
def new_project_create(run_state: "RunState") -> None:
    """Actually create a project: fill the New Project dialog and click Create.

    Create emits SaveProjectInfoCommand + ReloadIntoProjectCommand; the latter
    reloads the engine into the new map, so this asserts on the command log
    rather than a golden (the frame after a reload is not stable). Both are
    logged before they execute, so the entries survive the reload. It also
    proves the reload path does not crash: a stale-RmlUi use-after-free on
    teardown would exit the engine and the run would fail.
    """
    left = _open_gallery(run_state)
    run_state.click(*panel_point(left, TOOLBAR["new_project"]), delay=Delay.S_1)
    run_state.click(*dialog_point(run_state, DIALOG["new_project_name"]), delay=Delay.MS_200)
    run_state.type_text("E2E created")
    run_state.key("Return", delay=Delay.MS_300)
    for field, value in (("new_project_size_x", "12"), ("new_project_size_y", "14")):
        run_state.fill_text(
            *dialog_point(run_state, DIALOG[field]),
            value,
            click_delay=Delay.MS_200,
            commit_delay=Delay.MS_250,
        )
    run_state.click(*dialog_point(run_state, DIALOG["new_project_create"]), delay=Delay.S_2_5)

    # Save persists the project; the reload reads it back and boots into the new
    # map, where the engine loads it (LoadProjectCommand). The dialog fields do
    # not reach the log (neither command serializes), so assert the trio fired,
    # which is what "Create made a real, loadable project" means.
    run_state.assert_command("SaveProjectInfoCommand")
    run_state.assert_command("ReloadIntoProjectCommand")
    run_state.assert_command("LoadProjectCommand")


@scenario()
def project_round_trip(run_state: "RunState") -> None:
    """Create a project, then reopen it through Load -- proving it is on disk
    and openable.

    Create writes the project and reloads into it; the Load dialog must then
    list the `.sdd` folder, and selecting it reloads back into it. Two reloads,
    so this asserts on the command log rather than goldens. Guards the engine
    ListDir directory-listing gap: a regression there empties Load.
    """
    left = panel_left(run_state)
    run_state.focus()

    run_state.click(*panel_point(left, TOOLBAR["new_project"]), delay=Delay.S_1)
    run_state.click(*dialog_point(run_state, DIALOG["new_project_name"]), delay=Delay.MS_200)
    run_state.type_text("RoundTrip")
    run_state.key("Return", delay=Delay.MS_300)
    run_state.click(*dialog_point(run_state, DIALOG["new_project_create"]), delay=Delay.S_4)

    # Reloaded into the new project; Load must now list it.
    run_state.click(*panel_point(left, TOOLBAR["load"]), delay=Delay.S_1_5)
    run_state.screenshot("load-lists-project")
    run_state.click(*dialog_point(run_state, DIALOG["file_first_cell"]), delay=Delay.MS_500)
    run_state.click(*dialog_point(run_state, DIALOG["file_ok"]), delay=Delay.S_4)
    # Create + Load each reload; both entries survive in the append-only log.
    run_state.assert_command_at_least("ReloadIntoProjectCommand", 2)
    run_state.screenshot("after-load")


@scenario()
def project_save_as(run_state: "RunState") -> None:
    """Save As writes the current project under a new name and reloads into it.

    Emits SetProjectNamePath + SaveProjectInfo + Save + Reload, as Lua's
    Project:Save does for a new project. The name-input row pushes the dialog
    footer down, so this uses the taller dialog's OK position.
    """
    left = panel_left(run_state)
    run_state.focus()
    run_state.click(*panel_point(left, TOOLBAR["save_as"]), delay=Delay.S_1)
    run_state.screenshot("save-as-open")
    run_state.click(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.MS_300)
    run_state.type_text("SavedProj")
    run_state.key("Return", delay=Delay.MS_300)
    run_state.click(*dialog_point(run_state, DIALOG["file_ok_name"]), delay=Delay.S_4)
    run_state.assert_command("SetProjectNamePathCommand")
    run_state.assert_command("SaveProjectInfoCommand")
    run_state.assert_command("SaveCommand")
    run_state.assert_command("ReloadIntoProjectCommand")
    # The reload must actually complete: a screenshot here fails the run if the
    # engine died reloading (a crash would exit it before this capture).
    run_state.move(1280, 700, delay=Delay.S_6)
    run_state.screenshot("after-reload")


@scenario()
def project_thumbnail(run_state: "RunState") -> None:
    """Saving captures a map thumbnail that the Open dialog shows.

    Save As saves the project (grabbing a screenshot of the map on the draw
    after the save) and reloads into it; the Open dialog then renders that
    screenshot as the project's grid image instead of a bare folder.
    """
    left = panel_left(run_state)
    run_state.focus()
    run_state.click(*panel_point(left, TOOLBAR["save_as"]), delay=Delay.S_1)
    run_state.click(*dialog_point(run_state, DIALOG["file_name"]), delay=Delay.MS_300)
    run_state.type_text("ShotProj")
    run_state.key("Return", delay=Delay.MS_300)
    run_state.click(*dialog_point(run_state, DIALOG["file_ok_name"]), delay=Delay.S_6)
    # Open the project list; the saved project shows its map thumbnail.
    run_state.click(*panel_point(left, TOOLBAR["load"]), delay=Delay.S_2)
    run_state.screenshot("open-with-thumbnail")


@scenario()
def large_map_create(run_state: "RunState") -> None:
    """Create the largest map the dialog allows (32x32) and boot into it.

    The size fields clamp at 32, so this is the biggest a user can make. A
    32x32 blank map is generated and reloaded into; the engine surviving to the
    screenshot (a bigger map is more memory and a slower generate) is the check.
    """
    left = panel_left(run_state)
    run_state.focus()
    run_state.click(*panel_point(left, TOOLBAR["new_project"]), delay=Delay.S_1)
    run_state.click(*dialog_point(run_state, DIALOG["new_project_name"]), delay=Delay.MS_200)
    run_state.type_text("BigMap")
    run_state.key("Return", delay=Delay.MS_300)
    for field, value in (("new_project_size_x", "32"), ("new_project_size_y", "32")):
        run_state.fill_text(
            *dialog_point(run_state, DIALOG[field]),
            value,
            click_delay=Delay.MS_200,
            commit_delay=Delay.MS_250,
        )
    run_state.click(*dialog_point(run_state, DIALOG["new_project_create"]), delay=Delay.S_6)
    run_state.assert_command("ReloadIntoProjectCommand")
    run_state.screenshot("big-map-loaded")


def _values(run_state: "RunState") -> dict[str, str]:
    values: dict[str, str] = {}
    for line in run_state.engine_log():
        _, _, tail = line.partition("dev-fields: ")
        if not tail or " = " not in tail:
            continue
        name, _, value = tail.strip().partition(" = ")
        values[name] = value.removesuffix(" (dragged)").strip()
    return values


def _open_gallery(run_state: "RunState") -> int:
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + GALLERY["dev_tab_x"], TAB_Y, delay=Delay.MS_400)
    run_state.click(*editor_point(left, "dev", "gallery"), delay=Delay.MS_800)
    return left
