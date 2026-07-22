from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Literal, cast

from ..models import PortFlags

if TYPE_CHECKING:
    from ..runner import E2ERun

CHONSOLE_FOR_UI: dict[str, Literal["lua", "rust"]] = {"chili": "lua", "rmlui": "lua", "rust": "rust"}


@dataclass(frozen=True)
class Registered:
    target: str
    scenario: str
    func: Callable[["E2ERun"], None]
    cases: dict[str, PortFlags]
    crop: str | None = None
    env: dict[str, str] = field(default_factory=dict)


REGISTERED: dict[str, Registered] = {}


def scenario(
    *,
    uis: tuple[str, ...] = ("rust",),
    crop: str | None = None,
    target: str | None = None,
    cases: Mapping[str, Mapping[str, str]] | None = None,
    env: dict[str, str] | None = None,
) -> Callable[[Callable[["E2ERun"], None]], Callable[["E2ERun"], None]]:

    def register(func: Callable[["E2ERun"], None]) -> Callable[["E2ERun"], None]:
        name = target or func.__name__.replace("_", "-")
        if name in REGISTERED:
            raise ValueError(f"duplicate scenario target: {name}")
        REGISTERED[name] = Registered(
            target=name,
            scenario=func.__name__,
            func=func,
            cases={case_name: _port_flags(flags) for case_name, flags in cases.items()}
            if cases is not None
            else _cases_for(name, uis),
            crop=crop,
            env=env or {},
        )
        return func

    return register


def _cases_for(target: str, uis: tuple[str, ...]) -> dict[str, PortFlags]:
    out: dict[str, PortFlags] = {}
    for ui in uis:
        chonsole = CHONSOLE_FOR_UI[ui]
        suffix = "rust" if ui == "rust" else f"lua-{ui}"
        out[f"{target}-{suffix}"] = cast(PortFlags, {"chonsole": chonsole, "ui": ui})
    return out


def _port_flags(flags: Mapping[str, str]) -> PortFlags:
    chonsole = flags.get("chonsole")
    ui = flags.get("ui")
    if chonsole not in {"lua", "rust"} or ui not in {"chili", "rmlui", "rust"}:
        raise ValueError(f"invalid scenario flags: {flags}")
    return cast(PortFlags, {"chonsole": chonsole, "ui": ui})
