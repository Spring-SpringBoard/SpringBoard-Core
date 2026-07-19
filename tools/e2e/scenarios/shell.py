"""The panel shell itself: tabs, every editor, dialogs, and notifications."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import (
    EDITORS,
    TAB_X,
    TAB_Y,
    TOOLBAR,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)
from scenarios.registry import scenario

# Kept local to this shell-level test: object scenarios cover the detailed
# selection model, while this one only needs a real selected object to prove
# the toolbar's Copy/Cut/Paste icons dispatch their own actions.
from scenarios.objects import _arm_tree, _open

if TYPE_CHECKING:
    from runner import E2ERun


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
def toolbar_actions(run_state: E2ERun) -> None:
    """Every Rust shell-toolbar icon invokes its own action.

    Project actions are opened and cancelled rather than accepted: the point is
    the action-to-dialog wiring, not creating files in an isolated e2e run.
    Clipboard actions use a selected tree and then compare the map, so a button
    that merely receives a click cannot pass.
    """
    run_state.focus()
    left = panel_left(run_state)

    # New Project has its own dialog.  Load, Import, Save (without a project
    # path), Save As, and Export all use the file dialog, with distinct visible
    # headings/configuration.  Capturing each gives the review a concise audit
    # trail of the icon row without mutating project state.
    run_state.click(*panel_point(left, TOOLBAR["new_project"]), delay=0.7)
    run_state.screenshot("new-project")
    run_state.key("Escape", delay=0.35)

    for action in ("load", "import", "save", "save_as", "export"):
        before = run_state.screenshot(f"before-{action}")
        run_state.click(*panel_point(left, TOOLBAR[action]), delay=0.65)
        opened = run_state.screenshot(f"{action}-dialog")
        run_state.assert_screenshot_pixels(before, opened, min_changed=2_000)
        run_state.key("Escape", delay=0.35)

    # Exact toolbar clicks, not their keyboard shortcuts.  Paste needs the
    # cursor ground hit; move it to a distinct map point before clicking the
    # icon so the second tree's placement is observable.
    left = _open(run_state, "features")
    _arm_tree(run_state, left)
    width, height = window_size(run_state)
    source = (width // 3 - 130, height // 2)
    target = (width // 3 + 220, height // 2 + 120)
    run_state.wheel(*source, clicks=8, up=True)
    run_state.click(*source, delay=0.8)
    run_state.key("Escape", delay=0.35)
    run_state.click(*source, delay=0.5)

    run_state.click(*panel_point(left, TOOLBAR["copy"]), delay=0.4)
    before_paste = run_state.screenshot("copied")
    run_state.move(*target, delay=0.25)
    mark = len(run_state.commands())
    run_state.click(*panel_point(left, TOOLBAR["paste"]), delay=0.8)
    pasted = run_state.screenshot("pasted")
    if not any(entry["data"].get("className") == "CompoundCommand" for entry in run_state.commands()[mark:]):
        raise AssertionError("toolbar Paste did not dispatch a grouped native command")
    run_state.assert_screenshot_pixels(before_paste, pasted, min_changed=400)

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
