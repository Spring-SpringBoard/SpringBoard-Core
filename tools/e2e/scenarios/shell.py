"""The panel shell itself: tabs, every editor, dialogs, and notifications."""

import shutil
from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.driver.utils.paths import GAME_DIRNAME

from .helpers.camera import zoom_map
from .helpers.geometry import (
    COLOR_PICKER,
    DIALOG,
    EDITORS,
    ENV_LIGHTING_COLORS,
    MISC_INFO_FIELDS,
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
from .helpers.objects import arm_tree as _arm_tree
from .helpers.objects import open_object_editor as _open
from .helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario(target="main-panel", crop="right-panel")
def main_panel_tabs(run_state: "RunState") -> None:
    run_state.focus()
    left = panel_left(run_state)
    for name, offset_x in TAB_X.items():
        run_state.click(left + offset_x, TAB_Y, delay=Delay.CONTROL)
        run_state.screenshot(f"tab-{name}")


@scenario()
def hide_interface(run_state: "RunState") -> None:
    """F5 hides native RmlUi and releases it back to normal map input.

    RmlUi contexts render through the engine, rather than widget DrawScreen,
    so `/hideinterface` must explicitly gate that renderer and its input path.
    The right-panel region is deliberately large: hiding it exposes the map and
    changes hundreds of thousands of pixels, whereas cursor movement cannot
    satisfy this assertion.
    """
    run_state.focus()
    width, height = window_size(run_state)
    before = run_state.screenshot("interface-shown")

    run_state.key("F5", delay=Delay.DIALOG)
    hidden = run_state.screenshot("interface-hidden")
    panel_region = (width - 500, 0, 500, height)
    run_state.assert_region_pixels(before, hidden, panel_region, min_changed=20_000)

    run_state.key("F5", delay=Delay.DIALOG)
    restored = run_state.screenshot("interface-restored")
    run_state.assert_region_pixels(hidden, restored, panel_region, min_changed=20_000)

    # The input gate only applies while hidden; on return, RmlUi controls must
    # immediately be live again.
    left = panel_left(run_state)
    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.DIALOG)
    map_tab = run_state.screenshot("map-tab-restored")
    run_state.assert_region_pixels(restored, map_tab, panel_region, min_changed=1_000)


# Every registered editor, so none of them is left untried. Tab -> how many
# editor buttons that tab has.
_TABS = (("objects",), ("map",), ("env",), ("misc",))


@scenario(crop="right-panel")
def all_editors(run_state: "RunState") -> None:
    """Open every editor in every tab. Editors are lazily created, so a broken
    one only shows up when its button is clicked."""
    run_state.focus()
    left = panel_left(run_state)

    for (tab_name,) in _TABS:
        run_state.click(left + TAB_X[tab_name], TAB_Y, delay=Delay.FRAME)
        for editor_name in EDITORS[tab_name]:
            run_state.click(*editor_point(left, tab_name, editor_name), delay=Delay.READY)
            run_state.screenshot(f"{tab_name}-{editor_name}")


@scenario(crop="right-panel")
def panel_tabs_are_choices(run_state: "RunState") -> None:
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

    run_state.click(left + TAB_X["objects"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "objects", "units"), delay=Delay.DIALOG)
    units = run_state.screenshot("units-selected")
    run_state.click(left + TAB_X["objects"], TAB_Y, delay=Delay.FRAME)
    objects_again = run_state.screenshot("objects-reselected")
    run_state.assert_screenshot_pixels(units, objects_again, max_changed=6_000)

    run_state.click(*editor_point(left, "objects", "units"), delay=Delay.FRAME)
    units_again = run_state.screenshot("units-reselected")
    run_state.assert_screenshot_pixels(objects_again, units_again, max_changed=6_000)


@scenario()
def field_modal_handoff(run_state: "RunState") -> None:
    """A generic colour modal must release its bindings before another editor
    accepts text input.

    This used to live in Scenario Info because that was where the regression
    surfaced. Its subject is the cross-panel widget lifecycle, not metadata.
    """
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["env"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "env", "lighting"), delay=Delay.SETTLE)
    run_state.click(*panel_point(left, ENV_LIGHTING_COLORS[0][1]), delay=Delay.SETTLE)
    run_state.click(ENV_LIGHTING_COLORS[0][2], COLOR_PICKER["sample_y"], delay=Delay.CONTROL)
    run_state.click(*dialog_point(run_state, DIALOG["color_ok_compact"]), delay=Delay.SETTLE)

    run_state.click(left + TAB_X["misc"], TAB_Y, delay=Delay.FRAME)
    run_state.click(*editor_point(left, "misc", "info"), delay=Delay.DIALOG)
    point, value = MISC_INFO_FIELDS[0]
    run_state.fill_text(*panel_point(left, point), value, click_delay=Delay.CONTROL, commit_delay=Delay.FRAME)
    run_state.assert_any_command("SetScenarioInfoCommand")


@scenario()
def import_action(run_state: "RunState") -> None:
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

    run_state.click(*panel_point(left, TOOLBAR["import"]), delay=Delay.READY)
    run_state.screenshot("import-dialog")
    import_dialog = run_state.control.dialog("import")
    import_dialog.select("springboard/projects/import_test.png")
    import_dialog.accept()
    run_state.assert_any_command("ImportDiffuseCommand")
    # Importing replaces every diffuse tile. It must be a real undoable edit so
    # the shared-session reset can restore the map for the next scenario.
    # This is a state reset, not a keyboard-shortcut test. Drive the native
    # command directly so the shared-session cleanup does not depend on X11
    # input timing.
    run_state.control.commands["UndoCommand"]()
    run_state.control.wait_for_update()
    run_state.assert_any_command("UndoCommand")

    # Import has two typed options, while Load has none. Opening Load straight
    # afterwards exercises the shrinking collection path without relying on a
    # screenshot diff; the harness rejects any RmlUi data-for diagnostic.
    run_state.click(*panel_point(left, TOOLBAR["load"]), delay=Delay.POLL)
    run_state.screenshot("load-after-import")
    run_state.control.dialog("load_project").cancel()


@scenario()
def clipboard_actions(run_state: "RunState") -> None:
    """The Copy/Cut/Paste toolbar icons round-trip a selected object.

    Exact toolbar clicks, not their keyboard shortcuts. Clicking the Paste icon
    leaves the cursor over the panel, so the paste must land at the map centre —
    in view — rather than off-screen behind the panel; the golden checks that
    centre region changed. Cut is then undone through the typed UndoCommand. Each step asserts its
    grouped native command and a real change to the map.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)
    width, height = window_size(run_state)
    source = (width // 3 - 130, height // 2)
    zoom_map(run_state, point=source)
    run_state.click(*source, delay=Delay.READY)
    run_state.key("Escape", delay=Delay.SETTLE)
    run_state.click(*source, delay=Delay.DIALOG)

    run_state.click(*panel_point(left, TOOLBAR["copy"]), delay=Delay.SETTLE)
    before_paste = run_state.screenshot("copied")
    mark = len(run_state.commands())
    run_state.click(*panel_point(left, TOOLBAR["paste"]), delay=Delay.READY)
    pasted = run_state.screenshot("pasted")
    if not any(entry["data"].get("className") == "CompoundCommand" for entry in run_state.commands()[mark:]):
        raise AssertionError("toolbar Paste did not dispatch a grouped native command")
    # The paste must appear near the centre of the map view (left of the panel),
    # not at the off-screen cursor over the Paste icon.
    centre = (left // 2 - 220, height // 2 - 220, 440, 440)
    run_state.assert_region_pixels(before_paste, pasted, centre, min_changed=200)

    mark = len(run_state.commands())
    run_state.click(*panel_point(left, TOOLBAR["cut"]), delay=Delay.READY)
    cut = run_state.screenshot("cut")
    if not any(entry["data"].get("className") == "CompoundCommand" for entry in run_state.commands()[mark:]):
        raise AssertionError("toolbar Cut did not dispatch its grouped native command")
    run_state.control.commands["UndoCommand"]()
    run_state.control.wait_for_update()
    run_state.assert_any_command("UndoCommand")
    restored = run_state.screenshot("cut-undone")
    run_state.assert_screenshot_pixels(cut, restored, min_changed=400)


@scenario()
def dialogs(run_state: "RunState") -> None:
    """Editors and dialogs that build controls outside the panel: Misc ->
    Diplomacy and the New Project dialog."""
    run_state.focus()
    left = panel_left(run_state)

    run_state.click(left + TAB_X["misc"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "misc", "diplomacy"), delay=Delay.READY)
    run_state.screenshot("diplomacy")

    run_state.click(*panel_point(left, TOOLBAR["new_project"]), delay=Delay.LOAD)
    run_state.screenshot_root("new-project")
    run_state.key("Escape", delay=Delay.FRAME)


@scenario(crop="project-status")
def project_status_bar(run_state: "RunState") -> None:
    """The always-available top-left project status bar.

    On a fresh boot it reads "Project not saved" and offers Open Project, Data
    Dir, Upload Log and Exit. The golden pins that the bar renders in the panel
    document (a single higher-level div) with its label and four buttons.
    """
    run_state.focus()
    run_state.golden("status-bar")


@scenario()
def notifications(run_state: "RunState") -> None:
    """Export with no saved project posts a warning notification (SB.NotifyWarn).
    In RmlUi that must come from RmlUiNotifications, not Chotify (which is Chili)."""
    run_state.focus()
    left = panel_left(run_state)

    run_state.screenshot("before")
    # Toolbar action buttons, 6th is Export.
    run_state.click(*panel_point(left, TOOLBAR["export"]), delay=Delay.LOAD)
    run_state.screenshot("warning")
    # time=3, so it must be gone a few seconds later (the editor runs paused, so
    # expiry cannot be driven off game seconds).
    run_state.move(left - 200, 400, delay=Delay.DEEP_RELOAD)
    run_state.screenshot("expired")


@scenario()
def export_warning(run_state: "RunState") -> None:
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
    run_state.click(*panel_point(left, TOOLBAR["export"]), delay=Delay.DIALOG)
    warning = run_state.screenshot("warning")
    run_state.assert_region_pixels(before, warning, strip, min_changed=300)

    # It carries its own timer (~4s) and clears without any interaction.
    run_state.move(left - 200, height // 2, delay=Delay.NOTIFICATION)
    expired = run_state.screenshot("expired")
    run_state.assert_region_pixels(warning, expired, strip, min_changed=300)
