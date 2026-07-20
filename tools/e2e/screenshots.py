from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

from process import run


@dataclass(frozen=True)
class Screenshot:
    name: str
    raw_path: Path
    png_path: Path
    crop: str | None = None


def convert_screenshot_file(shot: Screenshot) -> tuple[Screenshot, int]:
    start = time.monotonic()
    cmd = ["convert", str(shot.raw_path)]
    if shot.crop == "right-panel":
        width, height = identify_size(shot.raw_path)
        crop_width = min(500, width)
        cmd += ["-crop", f"{crop_width}x{height}+{width - crop_width}+0", "+repage"]
    elif shot.crop == "dev-console":
        # The console spans everything left of the 500dp panel, 300dp tall and
        # 92dp off the bottom. This deterministic crop deliberately excludes
        # the status strip: live CPU/FPS/RAM values are not golden-stable.
        width, height = identify_size(shot.raw_path)
        crop_width = max(1, width - 500)
        cmd += ["-crop", f"{crop_width}x300+0+{height - 392}", "+repage"]
    elif shot.crop == "status-commands":
        # The right 40% of the status strip contains the fixed undo/redo/clear
        # controls and edit journal. The left metrics column has intentionally
        # live system values, so it is inspected by the visual sweep rather
        # than compared against a static golden.
        width, height = identify_size(shot.raw_path)
        status_width = max(1, width - 500)
        command_x = round(status_width * 0.6)
        command_width = status_width - command_x
        cmd += ["-crop", f"{command_width}x92+{command_x}+{height - 92}", "+repage"]
    elif shot.crop == "project-status":
        # The top-left project status bar: left 8dp, top 8dp, ~420dp wide. A
        # generous box captures the location label and the four action buttons.
        cmd += ["-crop", "470x90+0+0", "+repage"]
    elif shot.crop == "no-console":
        # Everything above the console. A modal has to be captured full-width,
        # but the console below it prints the engine's boot log -- which carries
        # pointer addresses that differ every run, so including it makes any
        # golden flaky. Drop the bottom 392dp the console occupies.
        width, height = identify_size(shot.raw_path)
        cmd += ["-crop", f"{width}x{max(1, height - 392)}+0+0", "+repage"]
    cmd.append(str(shot.png_path))
    result = run(*cmd, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"convert screenshot failed: {result.stderr}")
    elapsed_ms = int((time.monotonic() - start) * 1000)
    return shot, elapsed_ms


def identify_size(path: Path) -> tuple[int, int]:
    result = run("identify", "-format", "%w %h", str(path), check=False)
    if result.returncode != 0:
        raise RuntimeError(f"identify failed: {result.stderr}")
    width, height = result.stdout.split()
    return int(width), int(height)
