from e2e.driver.state import RunState

from .geometry import OBJECTS, TAB_X, TAB_Y, editor_point, panel_left, panel_point


def open_object_editor(run_state: RunState, editor: str) -> int:
    left = panel_left(run_state)
    run_state.click(left + TAB_X["objects"], TAB_Y, delay=0.25)
    run_state.click(*editor_point(left, "objects", editor), delay=0.7)
    return left


def arm_tree(run_state: RunState, left: int) -> None:
    run_state.click(*panel_point(left, OBJECTS["feature_first_tree"]), delay=0.5)
