import time
from pathlib import Path

from .golden import compare as compare_golden
from .process import run
from .run_env import CASE_CROP, FAST, PANEL_TOLERANCE
from .run_state import RunState
from .screenshots import Screenshot, capture_editor
from .x11 import window_geometry


class CaptureMixin(RunState):
    def _skip_capture(self, kind: str, name: str) -> Path:
        """Fast mode: record that the step was reached, capture nothing. The
        returned path is a placeholder -- pixel asserts are no-ops in fast mode,
        so nothing ever reads it."""
        self.event(f"{kind}_skipped", name=name)
        return self.screenshot_dir / f"{name}.png"

    def screenshot(self, name: str) -> Path:
        if FAST:
            return self._skip_capture("screenshot", name)
        self.require_window()
        stem = f"{len(self.screenshots):02d}-{name}"
        capture_path = self.screenshot_dir / f"{stem}.captured.png"
        png_path = self.screenshot_dir / f"{stem}.png"
        shot = Screenshot(name=name, capture_path=capture_path, png_path=png_path, crop=self.case.crop)
        shot, elapsed_ms = self._capture_screenshot(shot)
        self.screenshots.append(shot)
        self.event("screenshot", name=name, path=str(png_path), elapsed_ms=elapsed_ms)
        return png_path

    def park_cursor(self) -> None:
        """Move the cursor somewhere harmless before a capture: the engine draws
        it, so wherever it rests becomes part of the image."""
        width, height = window_geometry(self.window)
        run("xdotool", "mousemove", "--window", self.window, str(width // 2), str(height - 4))
        time.sleep(0.25)

    def golden(
        self,
        name: str,
        crop: str | None = CASE_CROP,
        tolerance: int = PANEL_TOLERANCE,
        park: bool = True,
    ) -> Path:
        """Capture, then compare against the checked-in golden.

        `crop` defaults to the case's crop; pass it explicitly for a shot whose
        subject sits outside that region (a modal beside the panel, say).

        `tolerance` is the number of differing pixels to forgive. Leave it at 0
        for anything cropped to the panel -- those are bit-stable. A capture that
        includes the **map** is not: the engine's tree render varies by a few
        dozen pixels between runs, so those need a small budget. See `golden.py`.

        `park=False` keeps the cursor where it is. The default moves it out of
        shot, which would destroy any frame whose *subject* is cursor-dependent:
        a placement preview follows the cursor, and a mid-drag capture would end
        the drag somewhere else entirely.
        """
        if FAST:
            return self._skip_capture("golden", name)
        if park:
            self.park_cursor()
        stem = f"{len(self.screenshots):02d}-{name}"
        capture_path = self.screenshot_dir / f"{stem}.captured.png"
        png_path = self.screenshot_dir / f"{stem}.png"
        if crop is CASE_CROP:
            crop = self.case.crop
        shot = Screenshot(name=name, capture_path=capture_path, png_path=png_path, crop=crop)
        shot, _ = self._capture_screenshot(shot)
        self.screenshots.append(shot)

        status = "candidate (not written)"
        if not self.stage_goldens:
            status = compare_golden(
                self.case.name,
                name,
                png_path,
                update=self.update_golden,
                tolerance=tolerance,
            )
        self.golden_results.append((name, status))
        self.event("golden", name=name, status=status, path=str(png_path))
        return png_path

    def screenshot_root(self, name: str) -> Path:
        if FAST:
            return self._skip_capture("screenshot_root", name)
        self.require_window()
        stem = f"{len(self.screenshots):02d}-{name}"
        capture_path = self.screenshot_dir / f"{stem}.captured.png"
        png_path = self.screenshot_dir / f"{stem}.png"
        shot = Screenshot(name=name, capture_path=capture_path, png_path=png_path)
        shot, elapsed_ms = self._capture_screenshot(shot)
        self.screenshots.append(shot)
        self.event("screenshot_root", name=name, path=str(png_path), elapsed_ms=elapsed_ms)
        return png_path

    def _capture_screenshot(self, shot: Screenshot) -> tuple[Screenshot, int]:
        assert self.write_dir is not None
        request_path = self.write_dir / "e2e-screenshot-request.txt"
        self.event("capture_editor", request=str(request_path))
        return capture_editor(shot, request_path=request_path)
