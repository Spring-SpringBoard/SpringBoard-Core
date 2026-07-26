"""Resolving angle names to framings.

Angles live one per module in `angles/`, so adding one is adding a file. A sweep
names the angles it wants; nothing carries a second copy of their numbers.
"""

from importlib import import_module

from .framing import Framing

# Declaration order is the order a sweep visits them.
NAMES = ("close", "mid", "wide", "close_flat")


def angle(name: str) -> Framing:
    """The framing defined in `angles/<name>.py`."""
    if name not in NAMES:
        raise ValueError(f"no angle {name!r}. Angles: {', '.join(NAMES)}")
    module = import_module(f"{__package__}.angles.{name}")
    return module.ANGLE


def angles(names: tuple[str, ...] = ()) -> tuple[Framing, ...]:
    """The named framings, or every one of them when none are named."""
    return tuple(angle(name) for name in (names or NAMES))
