from collections.abc import Callable
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

from e2e.driver.utils.models import Environment

type Scenario = Callable[["RunState"], None]

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@dataclass(frozen=True)
class Registered:
    target: str
    scenario: str
    func: Scenario
    crop: str | None = None
    env: Environment = field(default_factory=dict[str, str])
    isolated: bool = False


REGISTERED: dict[str, Registered] = {}


def scenario(
    *,
    crop: str | None = None,
    target: str | None = None,
    env: Environment | None = None,
    isolated: bool = False,
) -> Callable[[Scenario], Scenario]:
    def register(func: Scenario) -> Scenario:
        name = target or func.__name__.replace("_", "-")
        if name in REGISTERED:
            raise ValueError(f"duplicate scenario target: {name}")
        REGISTERED[name] = Registered(
            target=name,
            scenario=func.__name__,
            func=func,
            crop=crop,
            env=dict[str, str]() if env is None else env,
            isolated=isolated,
        )
        return func

    return register
