import os
import time
from typing import cast

from .models import CommandData, CommandFields

CASE_CROP = "<case>"
PANEL_TOLERANCE = 20
SETTLE = 0.12
FAST = os.environ.get("SBC_E2E_FAST") == "1"


def nap(seconds: float) -> None:
    if not FAST:
        time.sleep(seconds)


_ENVELOPE_KEYS = frozenset({"className", "__cmd_id", "__preview"})


def command_fields(data: CommandData) -> CommandFields:
    options = data.get("opts")
    if options is not None:
        return {key: value for key, value in options.items() if value is not None}
    fields = {key: value for key, value in data.items() if key not in _ENVELOPE_KEYS and value is not None}
    return cast(CommandFields, fields)


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
