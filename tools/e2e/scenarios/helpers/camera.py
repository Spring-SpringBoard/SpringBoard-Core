"""Deterministic camera setup for domain scenarios."""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from e2e.driver.state import RunState


def zoom_map(
    run_state: "RunState",
    factor: float = 0.25,
    point: tuple[int, int] | None = None,
) -> None:
    """Frame the map through control, preserving an optional ground focus."""

    if point is not None and 0.0 < factor < 1.0:
        hit = run_state.control.camera.trace_screen_ray(*point)
        if hit["hit_type"] == 3:
            state = run_state.control.camera.get()
            if float(state["height"]) > 0.0 or float(state["distance"]) > 0.0:
                origin = state["controller_position"]
                target = hit["position"]
                blend = 1.0 - factor
                focus = [
                    float(origin[index]) + (float(target[index]) - float(origin[index])) * blend for index in range(3)
                ]
                run_state.control.camera.set(controller_position=focus)

    run_state.control.camera.zoom(factor)
    run_state.control.wait_for_update()
