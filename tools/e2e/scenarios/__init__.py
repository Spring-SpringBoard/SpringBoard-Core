"""E2E scenarios, one module per editor area.

Split so the areas can be worked on independently: a change to the Map scenarios
does not touch the file the Objects scenarios live in.

To add a scenario: write it in the module for its area and decorate it with
`@scenario(...)`. That is all -- it registers itself, as a scenario and as a
runnable target. Nothing here, and nothing in `cases.py`, needs editing.
"""

from typing import TYPE_CHECKING

from . import console as console
from . import env as env
from . import gallery as gallery
from . import map as map
from . import misc as misc
from . import objects as objects
from . import shell as shell
from . import visual_sweep as visual_sweep
from .registry import REGISTERED

if TYPE_CHECKING:
    from ..runner import E2ERun
else:
    from ..run_state import RunState as E2ERun


def run_scenario(run_state: E2ERun) -> None:
    name = run_state.case.scenario
    for registered in REGISTERED.values():
        if registered.scenario == name:
            registered.func(run_state)
            return
    known = ", ".join(sorted(r.scenario for r in REGISTERED.values()))
    raise ValueError(f"unknown scenario: {name} (known: {known})")
