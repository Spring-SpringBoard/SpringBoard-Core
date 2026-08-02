"""Stateful workflows that deliberately cover several project operations per boot."""

from collections.abc import Callable
from typing import TYPE_CHECKING

from .helpers.registry import scenario
from .map.project import _map_export, _map_roundtrip
from .map.state import _editor_state_roundtrip
from .project import _large_map_create, _project_round_trip, _project_save_as, _project_thumbnail

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario(target="project-workflows", isolated=True)
def project_workflows(run_state: "RunState") -> None:
    """Exercise project persistence, large-map creation, Save As, and thumbnails."""
    _step(run_state, "project-round-trip", _project_round_trip)
    _step(run_state, "editor-state-roundtrip", _editor_state_roundtrip)
    _step(run_state, "large-map-create", _large_map_create)
    _step(run_state, "project-save-as", _project_save_as)
    _step(run_state, "project-thumbnail", _project_thumbnail)


@scenario(target="map-workflows", isolated=True)
def map_workflows(run_state: "RunState") -> None:
    """Export and reopen maps in one process, keeping each pipeline explicit."""
    _step(run_state, "map-export", _map_export)
    _clear_test_maps(run_state)
    _step(run_state, "map-roundtrip", _map_roundtrip)


def _step(run_state: "RunState", name: str, function: Callable[["RunState"], None]) -> None:
    run_state.begin_scenario()
    run_state.event("workflow_step_start", name=name)
    try:
        function(run_state)
    except Exception as error:
        run_state.event("workflow_step_end", name=name, status="failed", error=str(error))
        raise
    run_state.event("workflow_step_end", name=name, status="complete")


def _clear_test_maps(run_state: "RunState") -> None:
    assert run_state.write_dir is not None
    maps_dir = run_state.write_dir / "maps"
    if not maps_dir.is_dir():
        return
    for path in maps_dir.iterdir():
        if path.is_file() or path.is_symlink():
            path.unlink()
