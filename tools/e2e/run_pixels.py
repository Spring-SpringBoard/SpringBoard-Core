from __future__ import annotations

import subprocess
from pathlib import Path

from process import run
from run_env import FAST


class PixelMixin:
    """Image measurements over captured frames.

    Whole-frame comparison is close to useless in this UI -- the dev console
    prints a line or two a second and the definition thumbnails spin, so any two
    frames differ by thousands of pixels no matter what is tested. These restrict
    the question to a region, or to "how many pixels of one colour are here",
    which is what actually distinguishes a real change from the ambient churn.
    """

    def count_color(
        self,
        shot: Path,
        region: tuple[int, int, int, int],
        color: str = "#00FF00",
        fuzz: str = "12%",
    ) -> int:
        """Pixels of one colour inside an `(x, y, w, h)` box.

        For overlays the editor draws in a flat colour -- the selection box is
        pure green -- this is worth far more than comparing frames: the map sways
        in the wind and the panel animates, so "how many pixels changed" is mostly
        noise, while "is the green box there" is exact.
        """
        raw = self._source_image(shot)

        x, y, width, height = region
        result = subprocess.run(
            # Mark the matches white, *then* blacken everything that is not white
            # with the fuzz switched off. The obvious order -- blacken the
            # non-matches first -- is a trap: for a near-black target colour the
            # black it just painted is itself within fuzz of the target, so every
            # pixel comes back a match.
            [
                "convert", str(raw),
                "-crop", f"{width}x{height}+{x}+{y}", "+repage",
                "-fuzz", fuzz,
                "-fill", "white", "-opaque", color,
                "-fuzz", "0%",
                "-fill", "black", "+opaque", "white",
                "-format", "%[fx:int(mean*w*h)]", "info:",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(f"ImageMagick failed: {result.stderr.strip()}")
        count = int(result.stdout.strip())
        self.event("count_color", shot=shot.name, color=color, count=count)
        return count

    def assert_region_pixels(
        self,
        before: Path,
        after: Path,
        region: tuple[int, int, int, int],
        *,
        min_changed: int = 0,
        max_changed: int | None = None,
    ) -> int:
        """`assert_screenshot_pixels`, restricted to one `(x, y, w, h)` box.

        Whole-frame comparisons are close to useless in this UI: the dev console
        prints a line or two every second and the definition thumbnails spin, so
        any two frames differ by thousands of pixels no matter what is being
        tested. Compare the patch of screen the assertion is actually about.
        """
        x, y, width, height = region
        crops = []
        for shot in (before, after):
            raw = self._source_image(shot)
            cropped = raw.with_name(f"{raw.stem}-crop.png")
            run(
                "convert",
                str(raw),
                "-crop",
                f"{width}x{height}+{x}+{y}",
                "+repage",
                str(cropped),
            )
            crops.append(cropped)
        return self._compare(crops[0], crops[1], min_changed, max_changed)

    def assert_screenshot_pixels(
        self,
        before: Path,
        after: Path,
        *,
        min_changed: int = 0,
        max_changed: int | None = None,
    ) -> int:
        """Assert an exact changed-pixel range between two captured frames.

        Compare the immediate XWD captures so this works with both deferred
        `raw` conversion and immediate `png` capture modes.
        """
        if FAST:
            self.event("assert_pixels_skipped")
            return 0
        return self._compare(
            self._source_image(before),
            self._source_image(after),
            min_changed,
            max_changed,
        )

    def _source_image(self, shot: Path) -> Path:
        """The image to measure for a captured shot.

        The raw XWD where it survives (in `raw` mode the PNGs are not written
        until the run ends), otherwise the PNG -- `golden` converts and deletes
        its raw immediately.
        """
        for captured in self.screenshots:
            if captured.png_path == shot:
                if captured.raw_path.exists():
                    return captured.raw_path
                return captured.png_path
        raise AssertionError(f"unknown screenshot {shot}")

    def _compare(
        self,
        before: Path,
        after: Path,
        min_changed: int,
        max_changed: int | None,
    ) -> int:
        result = subprocess.run(
            ["compare", "-metric", "AE", str(before), str(after), "null:"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode not in (0, 1):
            raise AssertionError(f"ImageMagick compare failed: {result.stderr.strip()}")
        try:
            changed = int(float(result.stderr.strip()))
        except ValueError as exc:
            raise AssertionError(f"invalid compare metric: {result.stderr!r}") from exc

        if changed < min_changed or (max_changed is not None and changed > max_changed):
            expected = f">= {min_changed}"
            if max_changed is not None:
                expected += f" and <= {max_changed}"
            raise AssertionError(
                f"expected changed pixels {expected}, got {changed}: "
                f"{before.name} -> {after.name}"
            )
        self.event(
            "assert_pixels",
            before=before.name,
            after=after.name,
            changed=changed,
            min=min_changed,
            max=max_changed,
        )
        return changed
