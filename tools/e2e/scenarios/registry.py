"""Self-registering scenarios.

A scenario declares its own cases with `@scenario(...)`, in the file it lives
in. There is no central list to keep in step -- adding a scenario means adding
one function:

    @scenario(crop="right-panel")
    def def_grid(run_state: E2ERun) -> None:
        ...

That is immediately runnable as `just test-e2e def-grid`: the target is the
function name in kebab-case, and the case is the native UI.

A scenario that also runs against the Lua UIs lists the implementations it
supports; each becomes one case, and the Lua UIs pair with the Lua chonsole:

    @scenario(uis=("chili", "rmlui", "rust"), crop="right-panel")

Cases are named `<target>-rust` and `<target>-lua-<ui>` -- the names the golden
images are already filed under.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

#: The UI implementation each case drives, and the chonsole that goes with it.
#: The Lua UIs are only ever run against the Lua chonsole.
CHONSOLE_FOR_UI = {"chili": "lua", "rmlui": "lua", "rust": "rust"}


@dataclass(frozen=True)
class Registered:
    target: str
    scenario: str
    func: Callable
    #: Case name -> engine flags. One entry per implementation the scenario runs.
    cases: dict[str, dict[str, str]]
    crop: str | None = None
    #: Environment overriding the harness defaults, for a scenario that needs one
    #: of the things the harness normally holds still (the cursor tooltip).
    env: dict[str, str] = field(default_factory=dict)


REGISTERED: dict[str, Registered] = {}


def scenario(
    *,
    uis: tuple[str, ...] = ("rust",),
    crop: str | None = None,
    target: str | None = None,
    cases: dict[str, dict[str, str]] | None = None,
    env: dict[str, str] | None = None,
) -> Callable[[Callable], Callable]:
    """Register the decorated function as a scenario, and as its own e2e target.

    Defaults to the native UI alone, which is what a new scenario is nearly
    always for. `cases` overrides the derived naming for the one scenario whose
    cases vary something other than the UI (the chonsole).
    """

    def register(func: Callable) -> Callable:
        name = target or func.__name__.replace("_", "-")
        if name in REGISTERED:
            raise ValueError(f"duplicate scenario target: {name}")
        REGISTERED[name] = Registered(
            target=name,
            scenario=func.__name__,
            func=func,
            cases=cases if cases is not None else _cases_for(name, uis),
            crop=crop,
            env=env or {},
        )
        return func

    return register


def _cases_for(target: str, uis: tuple[str, ...]) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for ui in uis:
        chonsole = CHONSOLE_FOR_UI[ui]
        suffix = "rust" if ui == "rust" else f"lua-{ui}"
        out[f"{target}-{suffix}"] = {"chonsole": chonsole, "ui": ui}
    return out
