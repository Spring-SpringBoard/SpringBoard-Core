import os
import time
from enum import Enum


class Delay(float, Enum):
    MS_20 = 0.02
    MS_30 = 0.03
    MS_50 = 0.05
    MS_60 = 0.06
    MS_80 = 0.08
    MS_100 = 0.1
    MS_120 = 0.12
    MS_130 = 0.13
    MS_150 = 0.15
    MS_180 = 0.18
    MS_200 = 0.2
    MS_220 = 0.22
    MS_250 = 0.25
    MS_300 = 0.3
    MS_350 = 0.35
    MS_400 = 0.4
    MS_450 = 0.45
    MS_500 = 0.5
    MS_550 = 0.55
    MS_600 = 0.6
    MS_700 = 0.7
    MS_800 = 0.8
    MS_900 = 0.9
    S_1 = 1.0
    S_1_5 = 1.5
    S_2 = 2.0
    S_2_5 = 2.5
    S_3 = 3.0
    S_4 = 4.0
    S_5 = 5.0
    S_6 = 6.0
    S_7 = 7.0
    S_8 = 8.0
    S_9 = 9.0


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
