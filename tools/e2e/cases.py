from dataclasses import dataclass, field

from .models import PortFlags
from .scenarios.registry import REGISTERED


@dataclass(frozen=True)
class Case:
    name: str
    flags: PortFlags
    scenario: str
    crop: str | None = None
    tags: frozenset[str] = field(default_factory=frozenset)
    env: dict[str, str] = field(default_factory=dict)


def targets() -> tuple[str, ...]:
    return tuple(sorted(REGISTERED))


TARGETS = targets()


def select_cases(targets: list[str], tags: list[str]) -> list[Case]:
    """Cases matching every requested tag, across the requested targets.

    `select_cases(["all"], ["ui:rust"])` runs only the native UI.
    """
    chosen = TARGETS if not targets or targets == ["all"] else targets
    wanted = set(tags)
    return [case for target in chosen for case in target_cases(target) if wanted <= case.tags]


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
            env=registered.env,
        )
        for name, flags in registered.cases.items()
    ]


def _tags_for(target: str, flags: PortFlags) -> frozenset[str]:
    tags = {f"target:{target}"}
    for key in ("ui", "chonsole"):
        if key in flags:
            tags.add(f"{key}:{flags[key]}")
    return frozenset(tags)
