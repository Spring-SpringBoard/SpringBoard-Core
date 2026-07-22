from dataclasses import dataclass
from pathlib import Path
from time import monotonic, sleep

from PIL import Image


@dataclass(frozen=True, slots=True)
class Screenshot:
    name: str
    capture_path: Path
    png_path: Path
    crop: str | None = None


def capture_editor(shot: Screenshot, *, request_path: Path, timeout_s: float = 10.0) -> tuple[Screenshot, int]:
    started = monotonic()
    shot.capture_path.unlink(missing_ok=True)
    pending_request = request_path.with_suffix(".pending")
    pending_request.write_text(str(shot.capture_path))
    pending_request.replace(request_path)
    deadline = monotonic() + timeout_s
    while monotonic() < deadline:
        if shot.capture_path.is_file():
            try:
                with Image.open(shot.capture_path) as image:
                    _crop_image(image, shot.crop).save(shot.png_path)
            except OSError:
                sleep(0.02)
                continue
            shot.capture_path.unlink(missing_ok=True)
            return shot, int((monotonic() - started) * 1000)
        sleep(0.02)
    raise TimeoutError(f"engine did not write screenshot within {timeout_s:.0f}s: {shot.png_path}")


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
    return image
