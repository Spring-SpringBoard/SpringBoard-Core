import os
import time
from enum import Enum


class Delay(float, Enum):
    POLL = 0.02
    EVENT = 0.05
    INPUT = 0.0
    CONTROL = 0.2
    FRAME = 0.3
    SETTLE = 0.4
    DIALOG = 0.6
    READY = 0.8
    LOAD = 1.0
    PROJECT_LOAD = 1.5
    PROJECT_CREATE = 2.5
    RELOAD = 3.0
    DEEP_RELOAD = 4.0
    SAVE = 5.0
    MAP_LOAD = 6.0
    MAP_EXPORT = 8.0
    ARCHIVE = 9.0


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
