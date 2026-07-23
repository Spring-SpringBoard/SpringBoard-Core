from pathlib import Path
from typing import TYPE_CHECKING, cast, override

from PIL import Image, ImageChops, ImageColor

from .state import PixelCheck, RunState
from .timing import FAST

if TYPE_CHECKING:
    from collections.abc import Iterable


class PixelMixin(RunState):
    @override
    def count_color(
        self,
        shot: Path,
        region: tuple[int, int, int, int],
        color: str = "#00FF00",
        fuzz: str = "12%",
    ) -> int:
        image = self._crop(shot, region)
        target = cast("tuple[int, int, int]", ImageColor.getrgb(color))
        threshold = round(float(fuzz.removesuffix("%")) * 255 / 100)
        count = sum(
            all(abs(channel - expected) <= threshold for channel, expected in zip(pixel, target, strict=True))
            for pixel in cast("Iterable[tuple[int, int, int]]", image.convert("RGB").getdata())
        )
        self.event("count_color", shot=shot.name, color=color, count=count)
        return count

    @override
    def assert_region_pixels(
        self,
        before: Path,
        after: Path,
        region: tuple[int, int, int, int],
        *,
        min_changed: int = 0,
        max_changed: int | None = None,
    ) -> None:
        self._queue_pixel_check(before, after, region, min_changed, max_changed)

    @override
    def assert_screenshot_pixels(
        self,
        before: Path,
        after: Path,
        *,
        min_changed: int = 0,
        max_changed: int | None = None,
    ) -> None:
        if FAST:
            self.event("assert_pixels_skipped")
            return
        self._queue_pixel_check(before, after, None, min_changed, max_changed)

    @override
    def _finish_pixel_assertions(self) -> list[str]:
        failures: list[str] = []
        for check in self.pending_pixel_checks:
            try:
                before = self._image(check.before)
                after = self._image(check.after)
                if check.region is not None:
                    before = self._crop_image(before, check.region)
                    after = self._crop_image(after, check.region)
                self._assert_changed(
                    before,
                    after,
                    check.before,
                    check.after,
                    check.min_changed,
                    check.max_changed,
                )
            except Exception as error:
                failures.append(f"pixels {check.before.name} -> {check.after.name}: {error}")
                self.event("assert_pixels_failed", before=check.before.name, after=check.after.name, error=str(error))
        self.pending_pixel_checks.clear()
        return failures

    def _queue_pixel_check(
        self,
        before: Path,
        after: Path,
        region: tuple[int, int, int, int] | None,
        min_changed: int,
        max_changed: int | None,
    ) -> None:
        self.pending_pixel_checks.append(PixelCheck(before, after, region, min_changed, max_changed))
        self.event(
            "assert_pixels_queued",
            before=before.name,
            after=after.name,
            region=region,
            min=min_changed,
            max=max_changed,
        )

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
        return self._crop_image(self._image(shot), region)

    def _crop_image(self, image: Image.Image, region: tuple[int, int, int, int]) -> Image.Image:
        x, y, width, height = region
        return image.crop((x, y, x + width, y + height))

    def _image(self, shot: Path) -> Image.Image:
        path = self._source_image(shot)
        with Image.open(path) as source:
            return source.copy()

    def _source_image(self, shot: Path) -> Path:
        return self._wait_for_screenshot(shot).shot.png_path
