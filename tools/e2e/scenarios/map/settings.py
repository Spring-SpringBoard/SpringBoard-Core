"""Map -> Settings scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.geometry import MAP, TAB_X, TAB_Y, editor_point, panel_left, panel_point
from e2e.scenarios.helpers.registry import scenario

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario()
def settings_panel(run_state: "RunState") -> None:
    """Map -> Settings: enabling a shading texture must open a texture dialog."""
    run_state.focus()
    left = panel_left(run_state)
    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.CONTROL)
    run_state.click(*editor_point(left, "map", "settings"), delay=Delay.DIALOG)
    run_state.screenshot("settings-open")
    # Specular checkbox: disable, then re-enable -> must open a texture dialog.
    run_state.click(*panel_point(left, MAP["settings_map_size"]), delay=Delay.DIALOG)
    run_state.screenshot("specular-off")
    run_state.click(*panel_point(left, MAP["settings_map_size"]), delay=Delay.READY)
    run_state.screenshot_root("specular-on-root")
