"""The runnable cases, derived entirely from the self-registered scenarios.

Nothing is listed here: a scenario decorated with `@scenario(...)` (see
`scenarios/registry.py`) *is* a target, and its cases come with it.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import scenarios  # noqa: F401  -- importing the modules runs the decorators
from scenarios.registry import REGISTERED


@dataclass(frozen=True)
class Case:
    name: str
    flags: dict[str, str]
    scenario: str
    crop: str | None = None
    tags: frozenset[str] = field(default_factory=frozenset)


def targets() -> tuple[str, ...]:
    return tuple(sorted(REGISTERED))


TARGETS = targets()


def select_cases(targets: list[str], tags: list[str]) -> list[Case]:
    """Cases matching every requested tag, across the requested targets.

    `select_cases(["all"], ["ui:rust"])` runs only the native UI.
    """
    chosen = TARGETS if not targets or targets == ["all"] else targets
    wanted = set(tags)
    return [
        case
        for target in chosen
        for case in target_cases(target)
        if wanted <= case.tags
    ]


def target_cases(target: str) -> list[Case]:
    registered = REGISTERED.get(target)
    if registered is None:
        raise ValueError(f"unknown target: {target}")
    return [
        Case(
            name=name,
            flags=flags,
            scenario=registered.scenario,
            crop=registered.crop,
            tags=_tags_for(target, flags),
        )
        for name, flags in registered.cases.items()
    ]


def _tags_for(target: str, flags: dict[str, str]) -> frozenset[str]:
    """Tags are derived from the case, so a new case is selectable without
    remembering to tag it: `target:<name>`, `ui:<impl>`, `chonsole:<impl>`."""
    tags = {f"target:{target}"}
    for key in ("ui", "chonsole"):
        if key in flags:
            tags.add(f"{key}:{flags[key]}")
    return frozenset(tags)
