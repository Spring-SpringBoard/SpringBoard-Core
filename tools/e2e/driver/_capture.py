from pathlib import Path
from time import monotonic
from typing import override

from PIL import Image, ImageChops

from e2e.fixtures.golden import compare as compare_golden

from .state import GoldenCheck, RunState
from .timing import FAST, Delay, Timeout, pause
from .utils.process import run
from .utils.run_env import CASE_CROP, PANEL_TOLERANCE
from .utils.screenshots import Screenshot, ScreenshotConversion
from .utils.x11 import window_geometry

# How far above the window's bottom edge a parked cursor sits. Inside the 92px
# status strip the goldens ignore, clear of the engine's edge-scroll band.
STATUS_PARK_INSET = 40


class CaptureMixin(RunState):
    @override
    def sync_input(self) -> None:
        """Wait only until input already sent to the engine has been consumed."""
        if not FAST:
            self._wait_for_input_frame()

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

    def park_cursor(self, *, x: int | None = None, y: int | None = None) -> None:
        """Move the cursor somewhere harmless before a capture.

        The bottom few pixels are part of the engine's edge-scroll region. The
        screenshot comparison ignores the 92px status strip, so park inside
        that strip but well above its bottom edge: the cursor stays out of the
        compared image without the camera scrolling south while it waits there.
        """
        width, height = window_geometry(self.window)
        # `EdgeMoveWidth` is a fraction of the view (0.003 -> ~4px at the
        # harness window size), so a park a few pixels off the bottom edge
        # scrolls the map. Keep the whole cursor inside the ignored strip
        # instead. The x sits left of the `status-commands` crop, which only
        # forgives its bottom 4 rows.
        safe_x = width // 4 if x is None else x
        safe_y = height - STATUS_PARK_INSET if y is None else y
        run("xdotool", "mousemove", "--window", self.window, str(safe_x), str(safe_y))
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
        if crop is CASE_CROP:
            crop = self.case.crop
        if park:
            self.park_cursor()
        stem = f"{len(self.screenshots):02d}-{name}"
        bmp_path = self.screenshot_dir / f"{stem}.bmp"
        png_path = self.screenshot_dir / f"{stem}.png"
        shot = Screenshot(name=name, bmp_path=bmp_path, png_path=png_path, crop=crop)
        capture_ms = self._capture_screenshot(shot)
        self.screenshots.append(shot)
        # The bottom 92px status strip deliberately carries live telemetry.
        # Full-frame assertions own map/editor interactions, while the dedicated
        # status test crops to its stable controls. Never let FPS/RAM text make
        # an otherwise identical full-frame UI test flaky.
        # The checked-in status reference was captured with the hardware cursor
        # clipped by the bottom edge. Ignore only those few pixels; the command
        # buttons above remain exact while the capture itself stays cursor-free.
        ignored_bottom = 92 if crop is None else (4 if crop == "status-commands" else 0)
        # Terrain edits refresh the engine's cached shading texture. A broad
        # map-only RGB ramp can move by a few units; keep panel crops exact and
        # allow that renderer quantisation only for full-frame captures.
        channel_tolerance = 8 if crop is None else 1
        self.pending_goldens.append(
            GoldenCheck(name, png_path, tolerance, channel_tolerance, capture_ms, ignored_bottom)
        )
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

    @override
    def wait_for_stable_region(self, region: tuple[int, int, int, int], attempts: int = 8) -> None:
        """Wait until two consecutive engine frames agree in ``region``."""
        if FAST:
            self.event("stable_region_skipped", region=region)
            return
        if attempts < 1:
            raise ValueError("stable region needs at least one comparison")
        previous = self._stability_capture(0)
        try:
            for attempt in range(1, attempts + 1):
                current = self._stability_capture(attempt)
                if self._region_changed(previous, current, region) == 0:
                    current.unlink(missing_ok=True)
                    self.event("stable_region", region=region, frames=attempt + 1)
                    return
                previous.unlink(missing_ok=True)
                previous = current
        finally:
            previous.unlink(missing_ok=True)
        raise AssertionError(f"region {region} did not settle within {attempts + 1} engine frames")

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
                        channel_tolerance=check.channel_tolerance,
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
                channel_tolerance=check.channel_tolerance,
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
        started = monotonic()
        self.sync_input()
        self._capture_bmp(shot.bmp_path)
        self.screenshot_worker.submit(shot)
        return int((monotonic() - started) * 1000)

    def _stability_capture(self, index: int) -> Path:
        path = self.screenshot_dir / f".stability-{len(self.screenshots)}-{index}.bmp"
        self._capture_bmp(path)
        return path

    def _capture_bmp(self, path: Path) -> None:
        assert self.write_dir is not None
        path.unlink(missing_ok=True)
        request_path = self.write_dir / "e2e-screenshot-request.txt"
        pending_request = request_path.with_suffix(".pending")
        pending_request.write_text(str(path))
        pending_request.replace(request_path)
        self._wait_for_capture(path)

    @staticmethod
    def _region_changed(before: Path, after: Path, region: tuple[int, int, int, int]) -> int:
        x, y, width, height = region
        with Image.open(before) as source:
            before_region = source.crop((x, y, x + width, y + height)).convert("RGBA")
        with Image.open(after) as source:
            after_region = source.crop((x, y, x + width, y + height)).convert("RGBA")
        difference = ImageChops.difference(before_region, after_region)
        channels = difference.split()
        maximum = channels[0]
        for channel in channels[1:]:
            maximum = ImageChops.lighter(maximum, channel)
        return sum(maximum.histogram()[1:])

    def _wait_for_input_frame(self) -> None:
        """Make the next capture observe input sent immediately before it."""
        if not self._input_pending:
            return
        started = monotonic()
        self.control.wait_for_update()
        self._input_pending = False
        self.event("input_update_barrier", elapsed_ms=int((monotonic() - started) * 1000))

    def _wait_for_capture(self, path: Path) -> None:
        deadline = monotonic() + Timeout.COMMAND
        while monotonic() < deadline:
            if path.is_file():
                return
            self.assert_running()
            pause(Delay.POLL)
        raise TimeoutError(f"engine did not write screenshot within {float(Timeout.COMMAND):.0f}s: {path}")
