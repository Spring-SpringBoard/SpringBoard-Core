"""Shared constants and helpers for object scenarios."""

from typing import TYPE_CHECKING

from e2e.driver.utils.models import WorldPosition, parse_world_position
from e2e.driver.utils.run_env import command_fields

if TYPE_CHECKING:
    from e2e.driver.state import RunState
MAP_TOLERANCE = 4000
SELECTION_RECTANGLE_COLOR = "#45b0e6"
TOOLTIP_COLOR = "#0b0d0c"


def _tip_box(cursor_x: int, cursor_y: int) -> tuple[int, int, int, int]:
    return (cursor_x + 40, cursor_y + 30, 320, 90)


def _placed(run_state: "RunState", since: int | None = None) -> list[WorldPosition]:
    positions: list[WorldPosition] = []
    entries = run_state.case_commands() if since is None else run_state.commands()[since:]
    for entry in entries:
        data = entry["data"]
        if data.get("className") != "AddObjectCommand" or data.get("__preview"):
            continue
        params = command_fields(data).get("params")
        if not isinstance(params, dict):
            continue
        position = parse_world_position(params.get("pos"))
        if position is not None:
            positions.append(position)
    return positions


def _spread(placed: list[WorldPosition]) -> float:
    if len(placed) < 2:
        return 0.0
    xs = [pos["x"] for pos in placed]
    zs = [pos["z"] for pos in placed]
    return max(max(xs) - min(xs), max(zs) - min(zs))
