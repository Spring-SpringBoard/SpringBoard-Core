from collections.abc import Iterable
from pathlib import Path
from typing import cast

from PIL import Image, ImageChops, ImageColor

from .run_env import FAST
from .run_state import RunState


class PixelMixin(RunState):
    def count_color(
        self,
        shot: Path,
        region: tuple[int, int, int, int],
        color: str = "#00FF00",
        fuzz: str = "12%",
    ) -> int:
        image = self._crop(shot, region)
        target = cast(tuple[int, int, int], ImageColor.getrgb(color))
        threshold = round(float(fuzz.removesuffix("%")) * 255 / 100)
        count = sum(
            all(abs(channel - expected) <= threshold for channel, expected in zip(pixel, target, strict=True))
            for pixel in cast(Iterable[tuple[int, int, int]], image.convert("RGB").getdata())
        )
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
        return self._assert_changed(
            self._crop(before, region), self._crop(after, region), before, after, min_changed, max_changed
        )

    def assert_screenshot_pixels(
        self,
        before: Path,
        after: Path,
        *,
        min_changed: int = 0,
        max_changed: int | None = None,
    ) -> int:
        if FAST:
            self.event("assert_pixels_skipped")
            return 0
        return self._assert_changed(self._image(before), self._image(after), before, after, min_changed, max_changed)

    def _assert_changed(
        self,
        before_image: Image.Image,
        after_image: Image.Image,
        before: Path,
        after: Path,
        minimum: int,
        maximum: int | None,
    ) -> int:
        if before_image.size != after_image.size:
            raise AssertionError(f"image sizes differ: {before.name} -> {after.name}")
        changed = sum(
            pixel != (0, 0, 0, 0)
            for pixel in ImageChops.difference(before_image.convert("RGBA"), after_image.convert("RGBA")).getdata()
        )
        if changed < minimum or (maximum is not None and changed > maximum):
            expected = f">= {minimum}" if maximum is None else f">= {minimum} and <= {maximum}"
            raise AssertionError(f"expected changed pixels {expected}, got {changed}: {before.name} -> {after.name}")
        self.event("assert_pixels", before=before.name, after=after.name, changed=changed, min=minimum, max=maximum)
        return changed

    def _crop(self, shot: Path, region: tuple[int, int, int, int]) -> Image.Image:
        x, y, width, height = region
        return self._image(shot).crop((x, y, x + width, y + height))

    def _image(self, shot: Path) -> Image.Image:
        path = self._source_image(shot)
        with Image.open(path) as source:
            return source.copy()

    def _source_image(self, shot: Path) -> Path:
        for captured in self.screenshots:
            if captured.png_path == shot:
                return captured.png_path
        raise AssertionError(f"unknown screenshot {shot}")
