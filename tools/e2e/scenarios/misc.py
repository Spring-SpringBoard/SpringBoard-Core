"""Misc tab: Info, Teams."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import ACTION_Y, EDITOR_BUTTON_Y, TAB_X, TAB_Y, panel_left

if TYPE_CHECKING:
    from runner import E2ERun


def info_panel(run_state: E2ERun) -> None:
    """Repro for the colour leaking into Misc -> Info (O6).

    Pick a colour in Env -> Lighting, then switch to Misc -> Info and type.
    """
    run_state.focus()
    left = panel_left(run_state)
    # Env -> Lighting, open the Diffuse colour swatch and confirm a colour.
    run_state.click(left + TAB_X["env"], TAB_Y, delay=0.2)
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.4)
    run_state.click(left + 110, 310, delay=0.4)
    run_state.click_root(1160, 690, delay=0.2)
    run_state.click_root(1319, 899, delay=0.4)
    run_state.screenshot("after-color-pick")
    # Misc -> Info, then edit a text field.
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.3)
    run_state.click(left + 38, EDITOR_BUTTON_Y, delay=0.5)
    run_state.screenshot("info-open")
    run_state.click(left + 200, 200, delay=0.2)
    run_state.type_text("hello")
    run_state.screenshot("info-typed")


def teams_panel(run_state: E2ERun) -> None:
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["misc"], TAB_Y, delay=0.2)
    run_state.screenshot("misc-tab")
    run_state.click(left + 110, EDITOR_BUTTON_Y, delay=0.5)   # Teams (order 1)
    run_state.screenshot("teams-open")
    # "Add" action button. Adding repeatedly rebuilds the team list DOM, which is
    # where the use-after-free on stale elements showed up.
    for _ in range(3):
        run_state.click(left + 38, ACTION_Y, delay=0.4)
    run_state.screenshot("teams-added")


SCENARIOS = {
    "info_panel": info_panel,
    "teams_panel": teams_panel,
}
