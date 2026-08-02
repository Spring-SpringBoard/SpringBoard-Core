"""Shared constants and gestures for map scenarios."""

import time
from pathlib import Path
from typing import TYPE_CHECKING

from e2e.driver.timing import Delay, Timeout, pause
from e2e.scenarios.helpers.geometry import PARK_PANEL, panel_point

if TYPE_CHECKING:
    from e2e.driver.state import RunState
TERRAIN_PATTERN_PATH = "springboard/assets/core/brush_patterns/terrain/circle1.png"
# A stroke holds the button down and sweeps. The brush waits out an initial
# delay before a held button starts repeating, then dabs on a timer. Keep the
# full sweep so these cases continue to test the same drag gesture as before.
STROKE_STEPS = 8
STROKE_STEP_DELAY = Delay.STROKE_REPEAT
# One press always dabs once; the repeats are what the hold buys. Asserting a
# floor of 3 says the stroke kept painting, without pinning the exact count.
STROKE_MIN_DABS = 3
MAP_STROKE_PIXELS = 20000
MAP_SHIMMER = 200


def _paint_stroke(
    run_state: "RunState",
    left: int,
    x: int,
    y: int,
    dx: int = 220,
    dy: int = 120,
) -> None:
    run_state.press(x, y)
    for i in range(1, STROKE_STEPS + 1):
        run_state.move(
            round(x + dx * i / STROKE_STEPS),
            round(y + dy * i / STROKE_STEPS),
            delay=STROKE_STEP_DELAY,
        )
    run_state.release(x + dx, y + dy)
    run_state.move(*panel_point(left, PARK_PANEL), delay=Delay.DIALOG)


def _sweep(run_state: "RunState", left: int, width: int, height: int) -> None:
    # Keep the full drag and hold long enough for the brush repeat timer.
    x, y = width // 3, height // 2
    end_x, end_y = left - 200, y
    dx, dy = end_x - x, end_y - y
    run_state.press(x, y)
    for i in range(1, STROKE_STEPS + 1):
        run_state.move(
            round(x + dx * i / STROKE_STEPS),
            round(y + dy * i / STROKE_STEPS),
            delay=STROKE_STEP_DELAY,
        )
    run_state.release(end_x, end_y)


def _wait_for_archive(run_state: "RunState", stem: str, timeout_s: Timeout = Timeout.ARCHIVE) -> Path | None:
    assert run_state.write_dir is not None
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        matches = list(run_state.write_dir.rglob(f"{stem}*.sdz"))
        if matches:
            return matches[0]
        pause(Delay.FRAME)
    return None
