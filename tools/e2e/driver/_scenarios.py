"""E2E scenarios, one module per editor area.

Split so the areas can be worked on independently: a change to the Map scenarios
does not touch the file the Objects scenarios live in.

To add a scenario: write it in the module for its area and decorate it with
`@scenario(...)`. That is all -- it registers itself, as a scenario and as a
runnable target. Nothing here, and nothing in `cases.py`, needs editing.
"""

from typing import TYPE_CHECKING

from e2e.scenarios import console as console
from e2e.scenarios import gallery as gallery
from e2e.scenarios import misc as misc
from e2e.scenarios import mouse as _mouse  # noqa: F401
from e2e.scenarios import shell as shell
from e2e.scenarios import visual_sweep as visual_sweep
from e2e.scenarios import workflows as _workflows  # noqa: F401
from e2e.scenarios.env import lighting as _env_lighting  # noqa: F401
from e2e.scenarios.env import sky as _env_sky  # noqa: F401
from e2e.scenarios.env import water as _env_water  # noqa: F401
from e2e.scenarios.helpers.registry import REGISTERED, Registered
from e2e.scenarios.map import editors as _map_editors  # noqa: F401
from e2e.scenarios.map import grass as _map_grass  # noqa: F401
from e2e.scenarios.map import metal as _map_metal  # noqa: F401
from e2e.scenarios.map import project as _map_project  # noqa: F401
from e2e.scenarios.map import settings as _map_settings  # noqa: F401
from e2e.scenarios.map import state as _map_state  # noqa: F401
from e2e.scenarios.map import terrain as _map_terrain  # noqa: F401
from e2e.scenarios.map import texture as _map_texture  # noqa: F401
from e2e.scenarios.objects import brush as _objects_brush  # noqa: F401
from e2e.scenarios.objects import collision as _objects_collision  # noqa: F401
from e2e.scenarios.objects import features as _objects_features  # noqa: F401
from e2e.scenarios.objects import properties as _objects_properties  # noqa: F401
from e2e.scenarios.objects import selection as _objects_selection  # noqa: F401
from e2e.scenarios.objects import tooltips as _objects_tooltips  # noqa: F401
from e2e.scenarios.objects import units as _objects_units  # noqa: F401

if TYPE_CHECKING:
    from e2e.runner import E2ERun


def run_scenario(run_state: "E2ERun") -> None:
    name = run_state.case.scenario
    for registered in REGISTERED.values():
        if registered.scenario == name:
            registered.func(run_state)
            return
    known = ", ".join(sorted(r.scenario for r in REGISTERED.values()))
    raise ValueError(f"unknown scenario: {name} (known: {known})")


def registered_scenarios() -> dict[str, Registered]:
    return REGISTERED
