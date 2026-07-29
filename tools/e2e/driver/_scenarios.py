"""E2E scenarios, one module per editor area.

Split so the areas can be worked on independently: a change to the Map scenarios
does not touch the file the Objects scenarios live in.

To add a scenario: write it in the module for its area and decorate it with
`@scenario(...)`. That is all -- it registers itself, as a scenario and as a
runnable target. Nothing here, and nothing in `cases.py`, needs editing.
"""

from typing import TYPE_CHECKING

from e2e.scenarios import console as console
from e2e.scenarios import env as env
from e2e.scenarios import gallery as gallery
from e2e.scenarios import map as _map  # noqa: F401 - registers Map scenarios
from e2e.scenarios import misc as misc
from e2e.scenarios import objects as objects
from e2e.scenarios import shell as shell
from e2e.scenarios import visual_sweep as visual_sweep
from e2e.scenarios.helpers.registry import REGISTERED, Registered

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
