from dataclasses import dataclass, field

from e2e.driver._scenarios import registered_scenarios
from e2e.driver.utils.models import Environment, PortFlags

REGISTERED = registered_scenarios()
E2E_FLAGS: PortFlags = {"chonsole": "rust", "ui": "rust"}


@dataclass(frozen=True)
class Case:
    name: str
    flags: PortFlags
    scenario: str
    crop: str | None = None
    tags: frozenset[str] = frozenset()
    env: Environment = field(default_factory=dict[str, str])
    isolated: bool = False


def targets() -> tuple[str, ...]:
    return tuple(sorted(REGISTERED))


TARGETS = targets()


def select_cases(targets: list[str], tags: list[str]) -> list[Case]:
    """Cases matching every requested tag, across the requested targets.

    Every case runs with the native Rust UI and console.
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
            name=target,
            flags=E2E_FLAGS,
            scenario=registered.scenario,
            crop=registered.crop,
            tags=_tags_for(target),
            env=registered.env,
            isolated=registered.isolated,
        )
    ]


def _tags_for(target: str) -> frozenset[str]:
    return frozenset({f"target:{target}", "ui", "chonsole"})
