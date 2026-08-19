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
        # PNG conversion is deferred until the scenario finishes, so use a few
        # workers to drain a run's full-frame queue in parallel. Four keeps the
        # encoder from becoming the dominant end-of-test wait without taking
        # over the machine running the engine.
        self._executor = ThreadPoolExecutor(max_workers=4, thread_name_prefix="sbc-e2e-images")
        self._shots: dict[Path, Screenshot] = {}
        self._futures: dict[Path, Future[ScreenshotConversion]] = {}
        self._waited: set[Path] = set()
        self._closed = False

    def submit(self, shot: Screenshot) -> None:
        if self._closed:
            raise RuntimeError("screenshot worker is closed")
        if shot.png_path in self._shots:
            raise ValueError(f"screenshot already queued: {shot.png_path}")
        # Start encoding immediately in the background. Assertions can still
        # read the BMP while it exists, and otherwise wait on this future for
        # the PNG; the finalization step should not pay for every screenshot at
        # once after the scenario has already finished.
        self._shots[shot.png_path] = shot
        self._futures[shot.png_path] = self._executor.submit(_convert_screenshot, shot)

    def wait(self, png_path: Path) -> tuple[ScreenshotConversion, bool]:
        if png_path not in self._shots:
            raise AssertionError(f"unknown screenshot {png_path}")
        future = self._futures.get(png_path)
        if future is None:
            future = self._executor.submit(_convert_screenshot, self._shots[png_path])
            self._futures[png_path] = future
        conversion = future.result()
        newly_waited = png_path not in self._waited
        self._waited.add(png_path)
        return conversion, newly_waited

    def finish(self) -> tuple[ScreenshotConversion, ...]:
        try:
            for png_path, shot in self._shots.items():
                if png_path not in self._futures:
                    self._futures[png_path] = self._executor.submit(_convert_screenshot, shot)
            conversions = tuple(
                future.result() for png_path, future in self._futures.items() if png_path not in self._waited
            )
            self._waited.update(conversion.shot.png_path for conversion in conversions)
            return conversions
        finally:
            if not self._closed:
                self._executor.shutdown(wait=True)
                self._closed = True

    def source(self, png_path: Path) -> Path:
        """Return a complete image with the capture's final dimensions."""
        shot = self._shots.get(png_path)
        if shot is None:
            raise AssertionError(f"unknown screenshot {png_path}")
        # A crop is applied during PNG conversion. Reading its full-frame BMP
        # here would make assertions depend on encoder timing and coordinates.
        if shot.crop is None and shot.bmp_path.is_file():
            return shot.bmp_path
        return self.wait(png_path)[0].shot.png_path


def _convert_screenshot(shot: Screenshot) -> ScreenshotConversion:
    started = monotonic()
    try:
        image = _wait_for_bmp(shot.bmp_path)
        # E2E images are comparison artifacts, not distribution assets. A low
        # compression level preserves every pixel while substantially reducing
        # CPU time in the final conversion barrier.
        _crop_image(image, shot.crop).save(shot.png_path, compress_level=1)
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
    raise TimeoutError(f"engine did not write screenshot within {float(Timeout.COMMAND):.0f}s: {path}")


def _crop_image(image: Image.Image, crop: str | None) -> Image.Image:
    width, height = image.size
    if crop == "right-panel":
        return image.crop((max(0, width - 500), 0, width, height))
    if crop == "dev-console":
        return image.crop((0, max(0, height - 392), max(1, width - 500), height - 92))
    if crop == "dev-console-without-heading":
        # The engine-line count in the heading is intentionally live: it
        # includes diagnostics emitted by the process before this scenario
        # starts. Keep the console body and toolbar in the golden while leaving
        # that run-dependent text to the deterministic log assertions.
        return image.crop((0, max(0, height - 360), max(1, width - 500), height - 92))
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
