"""Fast native visual smoke sweep.

This deliberately does no editing: it opens every shipped Rust tab and editor
with short settles, then captures the resulting panel. It is the first visual
gate after a shell/style change, before slower behavioural E2Es and goldens.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import EDITORS, TAB_X, TAB_Y, editor_point, panel_left
from scenarios.registry import scenario

if TYPE_CHECKING:
    from runner import E2ERun


@scenario(target="rust-ui-sweep")
def rust_ui_sweep(run_state: E2ERun) -> None:
    """Fast visual pass over status strip plus every native tab/editor."""
    run_state.focus()
    left = panel_left(run_state)

    # Status is independent from F8; opening the console puts both neighbours
    # in one frame for inspection before touching the right-hand panel.
    run_state.key("F8", delay=0.2)
    run_state.screenshot("console-and-status")

    # Four shipped tabs, then every registered editor button in their display
    # order. Keep this intentionally quick: it is a rendering smoke pass, not a
    # substitute for the focused interaction scenarios.
    for tab in ("objects", "map", "env", "misc"):
        run_state.click(left + TAB_X[tab], TAB_Y, delay=0.12)
        run_state.screenshot(f"tab-{tab}")
        for editor in EDITORS[tab]:
            run_state.click(*editor_point(left, tab, editor), delay=0.12)
            run_state.screenshot(f"{tab}-{editor}")
