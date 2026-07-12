"""E2E scenarios, one module per editor area.

Split so the areas can be worked on independently: a change to the Map scenarios
does not touch the file the Objects scenarios live in.

To add a scenario: write it in the module for its area and decorate it with
`@scenario(...)`. That is all -- it registers itself, as a scenario and as a
runnable target. Nothing here, and nothing in `cases.py`, needs editing.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios import console, env, map, misc, objects, shell  # noqa: F401 -- registers
from scenarios.registry import REGISTERED

if TYPE_CHECKING:
    from runner import E2ERun


def run_scenario(run_state: E2ERun) -> None:
    name = run_state.case.scenario
    for registered in REGISTERED.values():
        if registered.scenario == name:
            registered.func(run_state)
            return
    known = ", ".join(sorted(r.scenario for r in REGISTERED.values()))
    raise ValueError(f"unknown scenario: {name} (known: {known})")
