"""The panel shell itself: tabs, every editor, dialogs, and notifications."""

import shutil
from typing import TYPE_CHECKING

from ..paths import GAME_DIRNAME
from .geometry import (
    DIALOG,
    EDITORS,
    TAB_X,
    TAB_Y,
    TOOLBAR,
    dialog_point,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)

# Kept local to this shell-level test: object scenarios cover the detailed
# selection model, while this one only needs a real selected object to prove
# the toolbar's Copy/Cut/Paste icons dispatch their own actions.
from .objects import _arm_tree, _open
from .registry import scenario

if TYPE_CHECKING:
    from ..runner import E2ERun
else:
    from ..run_state import RunState as E2ERun


@scenario(uis=("chili", "rmlui", "rust"), target="main-panel", crop="right-panel")
def main_panel_tabs(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    for name, offset_x in TAB_X.items():
        run_state.click(left + offset_x, TAB_Y, delay=0.18)
        run_state.screenshot(f"tab-{name}")


# Every registered editor, so none of them is left untried. Tab -> how many
# editor buttons that tab has.
_TABS = (("objects",), ("map",), ("env",), ("misc",))


@scenario(uis=("rmlui", "rust"), crop="right-panel")
def all_editors(run_state: E2ERun) -> None:
    """Open every editor in every tab. Editors are lazily created, so a broken
    one only shows up when its button is clicked."""
    run_state.focus()
    left = panel_left(run_state)

    for (tab_name,) in _TABS:
        run_state.click(left + TAB_X[tab_name], TAB_Y, delay=0.3)
        for editor_name in EDITORS[tab_name]:
            run_state.click(*editor_point(left, tab_name, editor_name), delay=0.7)
            run_state.screenshot(f"{tab_name}-{editor_name}")


@scenario(crop="right-panel")
def panel_tabs_are_choices(run_state: E2ERun) -> None:
    """Repeated panel tab clicks keep the chosen view open.

    Re-clicking Objects while Units is open must preserve Units. Re-clicking
    Units afterwards is intentionally part of the same sequence: before this
    regression, the top-level click silently discarded the backing editor while
    leaving its chrome visible, and the next Units click then closed it.

    The standard e2e boot has no unit definitions, so these panel-only captures
    are stable. RmlUi's live cursor/tooltip rendering still changes a small
    patch between frames; closing the editor clears far more pixels than that.
    """
    run_state.focus()
    left = panel_left(run_state)

    run_state.click(left + TAB_X["objects"], TAB_Y, delay=0.2)
    run_state.click(*editor_point(left, "objects", "units"), delay=0.45)
    units = run_state.screenshot("units-selected")
    run_state.click(left + TAB_X["objects"], TAB_Y, delay=0.3)
    objects_again = run_state.screenshot("objects-reselected")
    run_state.assert_screenshot_pixels(units, objects_again, max_changed=6_000)

    run_state.click(*editor_point(left, "objects", "units"), delay=0.3)
    units_again = run_state.screenshot("units-reselected")
    run_state.assert_screenshot_pixels(objects_again, units_again, max_changed=6_000)


@scenario()
def import_action(run_state: E2ERun) -> None:
    """The Import toolbar icon picks an image and dispatches its command.

    Import is the one toolbar action no other scenario drives (New/Load/Save
    As/Export are covered by gallery and map). Diffuse is the default type, so
    picking a file is the full path: icon -> dialog -> pick -> ImportDiffuseCommand.
    """
    run_state.focus()
    left = panel_left(run_state)

    # Import browses springboard/projects/; drop an image there for it to pick.
    assert run_state.write_dir is not None
    projects = run_state.write_dir / "springboard" / "projects"
    projects.mkdir(parents=True, exist_ok=True)
    game_image = run_state.write_dir / "games" / GAME_DIRNAME / "LuaUI" / "images" / "scenedit" / "area-add.png"
    shutil.copyfile(game_image, projects / "import_test.png")

    run_state.click(*panel_point(left, TOOLBAR["import"]), delay=0.7)
    run_state.screenshot("import-dialog")
    run_state.click(*dialog_point(run_state, DIALOG["asset_first_cell"]), delay=0.4)
    run_state.click(*dialog_point(run_state, DIALOG["file_ok_name"]), delay=0.6)
    run_state.assert_any_command("ImportDiffuseCommand")


@scenario()
def clipboard_actions(run_state: E2ERun) -> None:
    """The Copy/Cut/Paste toolbar icons round-trip a selected object.

    Exact toolbar clicks, not their keyboard shortcuts. Clicking the Paste icon
    leaves the cursor over the panel, so the paste must land at the map centre —
    in view — rather than off-screen behind the panel; the golden checks that
    centre region changed. Cut is then undone with Ctrl+Z. Each step asserts its
    grouped native command and a real change to the map.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)
    width, height = window_size(run_state)
    source = (width // 3 - 130, height // 2)
    run_state.wheel(*source, clicks=8, up=True)
    run_state.click(*source, delay=0.8)
    run_state.key("Escape", delay=0.35)
    run_state.click(*source, delay=0.5)

    run_state.click(*panel_point(left, TOOLBAR["copy"]), delay=0.4)
    before_paste = run_state.screenshot("copied")
    mark = len(run_state.commands())
    run_state.click(*panel_point(left, TOOLBAR["paste"]), delay=0.8)
    pasted = run_state.screenshot("pasted")
    if not any(entry["data"].get("className") == "CompoundCommand" for entry in run_state.commands()[mark:]):
        raise AssertionError("toolbar Paste did not dispatch a grouped native command")
    # The paste must appear near the centre of the map view (left of the panel),
    # not at the off-screen cursor over the Paste icon.
    centre = (left // 2 - 220, height // 2 - 220, 440, 440)
    run_state.assert_region_pixels(before_paste, pasted, centre, min_changed=200)

    mark = len(run_state.commands())
    run_state.click(*panel_point(left, TOOLBAR["cut"]), delay=0.8)
    cut = run_state.screenshot("cut")
    if not any(entry["data"].get("className") == "CompoundCommand" for entry in run_state.commands()[mark:]):
        raise AssertionError("toolbar Cut did not dispatch its grouped native command")
    run_state.key("ctrl+z", delay=0.8)
    restored = run_state.screenshot("cut-undone")
    run_state.assert_screenshot_pixels(cut, restored, min_changed=400)


@scenario(uis=("rmlui",))
def dialogs(run_state: E2ERun) -> None:
    """Editors and dialogs that build controls outside the panel: Misc ->
    Diplomacy and the New Project dialog."""
    run_state.focus()
    left = panel_left(run_state)

    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.2)
    run_state.click(*editor_point(left, "misc", "diplomacy"), delay=0.8)
    run_state.screenshot("diplomacy")

    run_state.click(*panel_point(left, TOOLBAR["new_project"]), delay=1.0)
    run_state.screenshot_root("new-project")
    run_state.key("Escape", delay=0.3)


@scenario(crop="project-status")
def project_status_bar(run_state: E2ERun) -> None:
    """The always-available top-left project status bar.

    On a fresh boot it reads "Project not saved" and offers Open Project, Data
    Dir, Upload Log and Exit. The golden pins that the bar renders in the panel
    document (a single higher-level div) with its label and four buttons.
    """
    run_state.focus()
    run_state.golden("status-bar")


@scenario(uis=("chili", "rmlui"))
def notifications(run_state: E2ERun) -> None:
    """Export with no saved project posts a warning notification (SB.NotifyWarn).
    In RmlUi that must come from RmlUiNotifications, not Chotify (which is Chili)."""
    run_state.focus()
    left = panel_left(run_state)

    run_state.screenshot("before")
    # Toolbar action buttons, 6th is Export.
    run_state.click(*panel_point(left, TOOLBAR["export"]), delay=1.0)
    run_state.screenshot("warning")
    # time=3, so it must be gone a few seconds later (the editor runs paused, so
    # expiry cannot be driven off game seconds).
    run_state.move(left - 200, 400, delay=4.0)
    run_state.screenshot("expired")


@scenario()
def export_warning(run_state: E2ERun) -> None:
    """Export with no saved project posts a warning toast in the native UI.

    The native replacement for Chotify: the toast appears immediately on the
    Export click (no dialog), floats over the map, and expires on its own.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    # The toast strip: top-centre, over the map (left of the 500-wide panel).
    strip = (width // 4, 55, width // 2, 220)

    before = run_state.screenshot("before")
    run_state.click(*panel_point(left, TOOLBAR["export"]), delay=0.6)
    warning = run_state.screenshot("warning")
    run_state.assert_region_pixels(before, warning, strip, min_changed=300)

    # It carries its own timer (~4s) and clears without any interaction.
    run_state.move(left - 200, height // 2, delay=5.0)
    expired = run_state.screenshot("expired")
    run_state.assert_region_pixels(warning, expired, strip, min_changed=300)
