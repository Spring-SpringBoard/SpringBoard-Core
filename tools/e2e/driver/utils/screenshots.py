from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from time import monotonic

from PIL import Image

from e2e.driver.timing import Delay, Timeout, pause


@dataclass(frozen=True, slots=True)
class Screenshot:
    name: str
    bmp_path: Path
    png_path: Path
    crop: str | None = None


@dataclass(frozen=True, slots=True)
class ScreenshotConversion:
    shot: Screenshot
    elapsed_ms: int


class ScreenshotWorker:
    def __init__(self) -> None:
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="sbc-e2e-images")
        self._futures: dict[Path, Future[ScreenshotConversion]] = {}
        self._waited: set[Path] = set()
        self._closed = False

    def submit(self, shot: Screenshot) -> None:
        if self._closed:
            raise RuntimeError("screenshot worker is closed")
        if shot.png_path in self._futures:
            raise ValueError(f"screenshot already queued: {shot.png_path}")
        self._futures[shot.png_path] = self._executor.submit(_convert_screenshot, shot)

    def wait(self, png_path: Path) -> tuple[ScreenshotConversion, bool]:
        future = self._futures.get(png_path)
        if future is None:
            raise AssertionError(f"unknown screenshot {png_path}")
        conversion = future.result()
        newly_waited = png_path not in self._waited
        self._waited.add(png_path)
        return conversion, newly_waited

    def finish(self) -> tuple[ScreenshotConversion, ...]:
        try:
            return tuple(future.result() for png_path, future in self._futures.items() if png_path not in self._waited)
        finally:
            if not self._closed:
                self._executor.shutdown(wait=True)
                self._closed = True


def _convert_screenshot(shot: Screenshot) -> ScreenshotConversion:
    started = monotonic()
    try:
        image = _wait_for_bmp(shot.bmp_path)
        _crop_image(image, shot.crop).save(shot.png_path)
    finally:
        shot.bmp_path.unlink(missing_ok=True)
    return ScreenshotConversion(shot=shot, elapsed_ms=int((monotonic() - started) * 1000))


def _wait_for_bmp(path: Path) -> Image.Image:
    deadline = monotonic() + Timeout.COMMAND
    while monotonic() < deadline:
        try:
            with Image.open(path) as image:
                return image.copy()
        except OSError:
            pause(Delay.POLL)
    raise TimeoutError(f"engine did not write screenshot within {Timeout.COMMAND:.0f}s: {path}")


def _crop_image(image: Image.Image, crop: str | None) -> Image.Image:
    width, height = image.size
    if crop == "right-panel":
        return image.crop((max(0, width - 500), 0, width, height))
    if crop == "dev-console":
        return image.crop((0, max(0, height - 392), max(1, width - 500), height - 92))
    if crop == "status-commands":
        panel_left = max(1, width - 500)
        start = round(panel_left * 0.6)
        return image.crop((start, max(0, height - 92), panel_left, height))
    if crop == "project-status":
        return image.crop((0, 0, min(470, width), min(90, height)))
    if crop == "without-status":
        return image.crop((0, 0, width, max(1, height - 92)))
    if crop == "no-console":
        return image.crop((0, 0, width, max(1, height - 392)))
    if crop is None:
        return image
    raise ValueError(f"unknown screenshot crop {crop!r}")
