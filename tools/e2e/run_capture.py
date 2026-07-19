from __future__ import annotations

import concurrent.futures
import shutil
import time
from pathlib import Path

from golden import compare as compare_golden
from process import run
from run_env import CASE_CROP, FAST, PANEL_TOLERANCE
from screenshots import Screenshot, convert_screenshot_file
from x11 import window_geometry


class CaptureMixin:
    """Screenshots, golden comparison, and their artifacts.

    Every capture grabs the engine window by id with `xwd`, then converts to
    PNG -- immediately in `png` mode, or deferred to a worker pool in `raw`
    mode, whichever the run was configured with. In fast mode nothing is
    captured at all; `_skip_capture` records that the step was reached.
    """

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
        raw_path = self.screenshot_dir / f"{stem}.xwd"
        png_path = self.screenshot_dir / f"{stem}.png"
        start = time.monotonic()
        run("xwd", "-silent", "-id", self.window, "-out", str(raw_path))
        if self.capture == "png":
            self.convert_screenshot(raw_path, png_path)
        elapsed_ms = int((time.monotonic() - start) * 1000)
        shot = Screenshot(
            name=name,
            raw_path=raw_path,
            png_path=png_path,
            crop=self.case.crop,
        )
        self.screenshots.append(shot)
        if self.review_images and self.capture == "raw":
            self.queue_conversion(shot)
        self.event(
            "screenshot",
            name=name,
            raw_path=str(raw_path),
            path=str(png_path),
            elapsed_ms=elapsed_ms,
            capture=self.capture,
        )
        return png_path

    def park_cursor(self) -> None:
        """Move the cursor somewhere harmless before a capture: the engine draws
        it, so wherever it rests becomes part of the image."""
        assert self.window is not None
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
        raw_path = self.screenshot_dir / f"{stem}.xwd"
        png_path = self.screenshot_dir / f"{stem}.png"
        run("xwd", "-silent", "-id", self.window, "-out", str(raw_path))
        if crop is CASE_CROP:
            crop = self.case.crop
        shot = Screenshot(name=name, raw_path=raw_path, png_path=png_path, crop=crop)
        convert_screenshot_file(shot)
        self.screenshots.append(shot)
        raw_path.unlink(missing_ok=True)

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
        """A full-frame capture, for a subject that sits outside the case's crop
        (a modal beside the panel).

        This captures the *engine window*, not the X root. Modals are RmlUi drawn
        inside that window, so there is nothing on the root to see -- and grabbing
        the whole desktop wrote ~29MB per shot through a separate, flakier path
        that intermittently failed mid-run (`xwd -root` returning 1). Capturing by
        window id is the same call every other screenshot already makes.
        """
        if FAST:
            return self._skip_capture("screenshot_root", name)
        self.require_window()
        stem = f"{len(self.screenshots):02d}-{name}"
        raw_path = self.screenshot_dir / f"{stem}.xwd"
        png_path = self.screenshot_dir / f"{stem}.png"
        start = time.monotonic()
        run("xwd", "-silent", "-id", self.window, "-out", str(raw_path))
        if self.capture == "png":
            self.convert_screenshot(raw_path, png_path)
        elapsed_ms = int((time.monotonic() - start) * 1000)
        shot = Screenshot(
            name=name,
            raw_path=raw_path,
            png_path=png_path,
            crop=None,
        )
        self.screenshots.append(shot)
        if self.review_images and self.capture == "raw":
            self.queue_conversion(shot)
        self.event(
            "screenshot_root",
            name=name,
            raw_path=str(raw_path),
            path=str(png_path),
            elapsed_ms=elapsed_ms,
            capture=self.capture,
        )
        return png_path

    def queue_conversion(self, shot: Screenshot) -> None:
        if self.image_pool is None:
            return
        self.image_futures.append(self.image_pool.submit(convert_screenshot_file, shot))

    def finish_conversions(self) -> None:
        for future in concurrent.futures.as_completed(self.image_futures):
            shot, elapsed_ms = future.result()
            self.event(
                "screenshot_convert",
                name=shot.name,
                raw_path=str(shot.raw_path),
                path=str(shot.png_path),
                elapsed_ms=elapsed_ms,
                async_workers=self.image_workers,
            )
        self.image_futures.clear()
        if self.image_pool is not None:
            self.image_pool.shutdown(wait=True)
            self.image_pool = None
        if self.capture != "png":
            for shot in self.screenshots:
                if not shot.png_path.is_file():
                    self.convert_screenshot(shot.raw_path, shot.png_path)
        self.discard_raw_captures()

    def discard_raw_captures(self) -> None:
        # The .xwd captures are uncompressed (14-29MB each) and are only an
        # intermediate for the PNG. Keeping them made artifacts/ grow into the
        # tens of GB. Drop each one once its PNG exists.
        for shot in self.screenshots:
            if shot.png_path.is_file() and shot.raw_path.is_file():
                shot.raw_path.unlink()

    def convert_screenshot(self, raw_path: Path, png_path: Path) -> None:
        convert_screenshot_file(Screenshot("", raw_path, png_path))

    def generate_contact_sheet(self) -> None:
        if not self.screenshots or shutil.which("montage") is None:
            return
        path = self.out_dir / "contact-sheet.png"
        cmd = [
            "montage",
            *[str(shot.png_path) for shot in self.screenshots],
            "-thumbnail",
            "480x263",
            "-label",
            "%f",
            "-tile",
            "2x",
            "-geometry",
            "+8+28",
            str(path),
        ]
        result = run(*cmd, check=False)
        if result.returncode == 0:
            self.contact_sheet = path
            self.event("contact_sheet", path=str(path))
        else:
            self.event("contact_sheet_failed", stderr=result.stderr)
