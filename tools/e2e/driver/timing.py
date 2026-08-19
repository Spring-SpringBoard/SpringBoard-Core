import os
import time
from enum import Enum


class Delay(float, Enum):
    """Small input pacing values; completion uses explicit waits."""

    POLL = 0.02
    EVENT = 0.01
    INPUT = 0.0
    CONTROL = 0.03
    FRAME = 0.04
    SETTLE = 0.06
    DIALOG = 0.08
    READY = 0.12
    LOAD = 0.20
    PROJECT_LOAD = 0.30
    PROJECT_CREATE = 0.50
    RELOAD = 0.70
    DEEP_RELOAD = 0.90
    SAVE = 1.00
    MAP_LOAD = 1.50
    MAP_EXPORT = 2.00
    ARCHIVE = 2.50
    NOTIFICATION = 4.20
    # A held painting stroke is explicitly testing an engine repeat timer.
    # This is intentional elapsed interaction time, not a UI-settle guess.
    STROKE_REPEAT = 0.10


class Timeout(float, Enum):
    SHUTDOWN = 4.0
    COMMAND = 10.0
    LOG = 15.0
    ARCHIVE = 20.0
    UI_START = 45.0


FAST = os.environ.get("SBC_E2E_FAST") == "1"


def pause(delay: Delay) -> None:
    if not FAST:
        time.sleep(delay.value)


TEXT_INTERVAL_MS = 10
