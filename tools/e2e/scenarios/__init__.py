"""E2E scenarios, one module per editor area.

Split so the areas can be worked on independently: a change to the Map
scenarios does not touch the file the Objects scenarios live in.

To add a scenario: write it in the module for its area, and list it in that
module's `SCENARIOS`. Nothing here needs editing.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Callable

from scenarios import console, env, map, misc, objects, shell

if TYPE_CHECKING:
    from runner import E2ERun


Scenario = Callable[["E2ERun"], None]


def _registry() -> dict[str, Scenario]:
    registry: dict[str, Scenario] = {}
    for module in (objects, map, env, misc, shell, console):
        for name, scenario in module.SCENARIOS.items():
            if name in registry:
                raise ValueError(f"duplicate scenario: {name}")
            registry[name] = scenario
    return registry


SCENARIOS = _registry()


def run_scenario(run_state: E2ERun) -> None:
    name = run_state.case.scenario
    scenario = SCENARIOS.get(name)
    if scenario is None:
        known = ", ".join(sorted(SCENARIOS))
        raise ValueError(f"unknown scenario: {name} (known: {known})")
    scenario(run_state)
