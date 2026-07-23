"""Fast native visual smoke sweep.

This deliberately does no editing: it opens every shipped Rust tab and editor
with short settles, then captures the resulting panel. It is the first visual
gate after a shell/style change, before slower behavioural E2Es and goldens.
"""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay

from .helpers.geometry import EDITORS, TAB_X, TAB_Y, editor_point, panel_left
from .helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario(target="rust-ui-sweep")
def rust_ui_sweep(run_state: "RunState") -> None:
    """Fast visual pass over status strip plus every native tab/editor."""
    run_state.focus()
    left = panel_left(run_state)

    # Status is independent from F8; opening the console puts both neighbours
    # in one frame for inspection before touching the right-hand panel.
    run_state.key("F8", delay=Delay.CONTROL)
    run_state.screenshot("console-and-status")

    # Four shipped tabs, then every registered editor button in their display
    # order. Keep this intentionally quick: it is a rendering smoke pass, not a
    # substitute for the focused interaction scenarios.
    for tab in ("objects", "map", "env", "misc"):
        run_state.click(left + TAB_X[tab], TAB_Y, delay=Delay.CONTROL)
        run_state.screenshot(f"tab-{tab}")
        for editor in EDITORS[tab]:
            run_state.click(*editor_point(left, tab, editor), delay=Delay.CONTROL)
            run_state.screenshot(f"{tab}-{editor}")
