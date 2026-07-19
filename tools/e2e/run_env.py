from __future__ import annotations

import os
import time

# Distinguishes "no crop override" from an explicit `crop=None` (full frame).
CASE_CROP = "<case>"

# Differing pixels a golden forgives by default. The panel renders bit-stably, so
# this only absorbs the odd antialiased edge -- a real UI change is hundreds of
# pixels at least. Captures that include the *map* need far more; see the
# scenarios' MAP_TOLERANCE.
PANEL_TOLERANCE = 20

# How long a pointer move is given to reach the engine before a button goes down
# on top of it.
SETTLE = 0.12

# Fast mode (`SBC_E2E_FAST=1`): a whole-suite smoke run that only asks "does each
# scenario execute and emit its commands". Captures are skipped, pixel diffs are
# neutralised, and every pacing delay collapses to zero -- only the drag
# move-before-press ordering survives, because without it a drag grabs the wrong
# point and the scenario fails for a reason that has nothing to do with the code.
FAST = os.environ.get("SBC_E2E_FAST") == "1"


def nap(seconds: float) -> None:
    """A pacing delay, elided entirely in fast mode."""
    if not FAST:
        time.sleep(seconds)


# Envelope bookkeeping, not command fields.
_ENVELOPE_KEYS = frozenset({"className", "__cmd_id", "__preview"})


def command_fields(data: dict) -> dict:
    """A command's fields, whichever envelope shape it used.

    There are two, and they are not interchangeable: `envelope()` nests the
    fields under `opts`, while `envelope_fields()` puts them flat on the command
    (SetObjectParamCommand, AddObjectCommand). Reading only `opts` makes a
    flat command look like it carries nothing at all.
    """
    # Partial-opts commands serialize unset fields as null; a null is "not
    # set", not a value a matcher should ever see.
    if isinstance(data.get("opts"), dict):
        return {key: value for key, value in data["opts"].items() if value is not None}
    return {
        key: value
        for key, value in data.items()
        if key not in _ENVELOPE_KEYS and value is not None
    }


MODIFIERS = (
    "Control_L",
    "Control_R",
    "Shift_L",
    "Shift_R",
    "Alt_L",
    "Alt_R",
    "Super_L",
    "Super_R",
)
MODIFIER_NAMES = {
    "ctrl": "Control_L",
    "control": "Control_L",
    "shift": "Shift_L",
    "alt": "Alt_L",
}
