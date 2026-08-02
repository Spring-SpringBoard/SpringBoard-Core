"""Deterministic camera setup for domain scenarios."""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from e2e.driver.state import RunState


def zoom_map(
    run_state: "RunState",
    factor: float = 0.21,
    point: tuple[int, int] | None = None,
) -> None:
    """Frame the map through the typed camera surface."""

    run_state.control.camera.zoom(factor, screen=point)
    run_state.control.wait_for_update()
