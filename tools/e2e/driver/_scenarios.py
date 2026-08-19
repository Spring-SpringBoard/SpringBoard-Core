"""E2E scenarios — developer console only."""

from typing import TYPE_CHECKING

from e2e.scenarios import console as console
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
