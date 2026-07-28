from pathlib import Path
from time import monotonic
from typing import override

from e2e.fixtures.golden import compare as compare_golden

from .state import GoldenCheck, RunState
from .timing import FAST, Delay, Timeout, pause
from .utils.process import run
from .utils.run_env import CASE_CROP, PANEL_TOLERANCE
from .utils.screenshots import Screenshot, ScreenshotConversion
from .utils.x11 import window_geometry


class CaptureMixin(RunState):
    @override
    def screenshot(self, name: str) -> Path:
        if FAST:
            return self._skip_capture("screenshot", name)
        self.require_window()
        stem = f"{len(self.screenshots):02d}-{name}"
        bmp_path = self.screenshot_dir / f"{stem}.bmp"
        png_path = self.screenshot_dir / f"{stem}.png"
        shot = Screenshot(name=name, bmp_path=bmp_path, png_path=png_path, crop=self.case.crop)
        elapsed_ms = self._capture_screenshot(shot)
        self.screenshots.append(shot)
        self.event("screenshot", name=name, bmp_path=str(bmp_path), path=str(png_path), elapsed_ms=elapsed_ms)
        self.assert_no_rml_diagnostics()
        return png_path

    def park_cursor(self) -> None:
        """Move the cursor somewhere harmless before a capture: the engine draws
        it, so wherever it rests becomes part of the image."""
        width, height = window_geometry(self.window)
        run("xdotool", "mousemove", "--window", self.window, str(width // 2), str(height - 4))
        pause(Delay.FRAME)

    @override
    def golden(
        self,
        name: str,
        crop: str | None = CASE_CROP,
        tolerance: int = PANEL_TOLERANCE,
        park: bool = True,
    ) -> Path:
        """Queue a capture for comparison against the checked-in golden at finish.

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
        bmp_path = self.screenshot_dir / f"{stem}.bmp"
        png_path = self.screenshot_dir / f"{stem}.png"
        if crop is CASE_CROP:
            crop = self.case.crop
        shot = Screenshot(name=name, bmp_path=bmp_path, png_path=png_path, crop=crop)
        capture_ms = self._capture_screenshot(shot)
        self.screenshots.append(shot)
        # The bottom 92px status strip deliberately carries live telemetry.
        # Full-frame assertions own map/editor interactions, while the dedicated
        # status test crops to its stable controls. Never let FPS/RAM text make
        # an otherwise identical full-frame UI test flaky.
        ignored_bottom = 92 if crop is None else 0
        self.pending_goldens.append(GoldenCheck(name, png_path, tolerance, capture_ms, ignored_bottom))
        self.event(
            "golden_queued",
            name=name,
            path=str(png_path),
            capture_ms=capture_ms,
        )
        self.assert_no_rml_diagnostics()
        return png_path

    @override
    def screenshot_root(self, name: str) -> Path:
        if FAST:
            return self._skip_capture("screenshot_root", name)
        self.require_window()
        stem = f"{len(self.screenshots):02d}-{name}"
        bmp_path = self.screenshot_dir / f"{stem}.bmp"
        png_path = self.screenshot_dir / f"{stem}.png"
        shot = Screenshot(name=name, bmp_path=bmp_path, png_path=png_path)
        elapsed_ms = self._capture_screenshot(shot)
        self.screenshots.append(shot)
        self.event("screenshot_root", name=name, bmp_path=str(bmp_path), path=str(png_path), elapsed_ms=elapsed_ms)
        self.assert_no_rml_diagnostics()
        return png_path

    def _skip_capture(self, kind: str, name: str) -> Path:
        self.event(f"{kind}_skipped", name=name)
        return self.screenshot_dir / f"{name}.png"

    @override
    def _finish_screenshots(self) -> list[str]:
        for conversion in self.screenshot_worker.finish():
            self.event(
                "screenshot_converted",
                name=conversion.shot.name,
                path=str(conversion.shot.png_path),
                elapsed_ms=conversion.elapsed_ms,
            )

        failures: list[str] = []
        for check in self.pending_goldens:
            conversion = self._wait_for_screenshot(check.path)
            started = monotonic()
            try:
                status = "candidate (not written)"
                if not self.stage_goldens:
                    status = compare_golden(
                        self.case.name,
                        check.name,
                        check.path,
                        update=self.update_golden,
                        tolerance=check.tolerance,
                        ignored_bottom=check.ignored_bottom,
                    )
            except Exception as error:
                status = f"failed: {error}"
                failures.append(f"golden {check.name}: {error}")
            self.golden_results.append((check.name, status))
            self.event(
                "golden",
                name=check.name,
                status=status,
                path=str(check.path),
                capture_ms=check.capture_ms,
                conversion_ms=conversion.elapsed_ms,
                compare_ms=int((monotonic() - started) * 1000),
            )
        self.pending_goldens.clear()
        return failures

    @override
    def _wait_for_screenshot(self, path: Path) -> ScreenshotConversion:
        conversion, newly_waited = self.screenshot_worker.wait(path)
        if newly_waited:
            self.event(
                "screenshot_converted",
                name=conversion.shot.name,
                path=str(path),
                elapsed_ms=conversion.elapsed_ms,
            )
        return conversion

    def _capture_screenshot(self, shot: Screenshot) -> int:
        assert self.write_dir is not None
        started = monotonic()
        shot.bmp_path.unlink(missing_ok=True)
        request_path = self.write_dir / "e2e-screenshot-request.txt"
        pending_request = request_path.with_suffix(".pending")
        pending_request.write_text(str(shot.bmp_path))
        pending_request.replace(request_path)
        self._wait_for_capture(shot.bmp_path)
        self.screenshot_worker.submit(shot)
        return int((monotonic() - started) * 1000)

    def _wait_for_capture(self, path: Path) -> None:
        deadline = monotonic() + Timeout.COMMAND
        while monotonic() < deadline:
            if path.is_file():
                return
            self.assert_running()
            pause(Delay.POLL)
        raise TimeoutError(f"engine did not write screenshot within {Timeout.COMMAND:.0f}s: {path}")
