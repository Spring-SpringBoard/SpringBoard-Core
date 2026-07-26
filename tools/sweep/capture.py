"""Engine session lifetime and image post-processing for the shader sweep.

Screenshots and every panel change go through the control channel, so nothing
here synthesises input or waits on a clock: `Control.capture` returns once the
image is on disk and includes every call made before it.
"""

import subprocess
import time
from pathlib import Path

from control import Control, connect_session
from control.transport import DISCOVERY_NAME
from e2e.driver.utils.process import run
from PIL import Image
from smoke.engine import launch_manual_detached
from smoke.engine import manual_write_dir as _manual_write_dir

# Waited for in order: the engine reports itself in-game long before the dev scene
# has framed the camera, and capturing in between photographs the default view.
READY_MARKER = "finished loading and is now ingame"
FRAMED_MARKER = "[sb-dev-scene] framed"
# The gadget says so rather than framing silently, and a capture then would
# photograph the boot overview camera with the subject a few pixels wide.
GAVE_UP_MARKER = "[sb-dev-scene] gave up framing"


def start_session(
    project: str,
    scene: str,
    modoptions: dict[str, str] | None = None,
) -> tuple[subprocess.Popen[bytes], Path, Control]:
    """Launch an editor on `project` with the dev scene placed, and attach to it.

    Models are held still and the console starts hidden, so nothing in a frame
    moves on its own and successive captures are comparable.
    """
    proc, write_dir = launch_manual_detached(
        project=project,
        scene=scene,
        extra_env={
            "SBC_HIDE_CONSOLE": "1",
            # No cursor tooltip in shot: it follows the pointer and lands on the subject.
            "SBC_HIDE_TOOLTIPS": "1",
            "SBC_STILL_MODELS": "1",
            # The control channel is opt-in, and this whole tool is the client.
            "SBC_CONTROL_FILE": str(_manual_write_dir() / DISCOVERY_NAME),
        },
        modoptions=modoptions,
    )
    try:
        _wait_ready(write_dir, proc)
        return proc, write_dir, connect_session(write_dir)
    except BaseException:
        stop_session(proc)
        raise


def stop_session(proc: subprocess.Popen[bytes]) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=15)


def image_size(path: Path) -> tuple[int, int]:
    """An image's pixel dimensions, via Pillow, which is already a dependency."""
    with Image.open(path) as image:
        return image.width, image.height


def crop(source: Path, destination: Path, region: str) -> Path:
    destination.parent.mkdir(parents=True, exist_ok=True)
    run("convert", str(source), "-crop", region, "+repage", str(destination))
    return destination


def contact_sheet(images: list[Path], destination: Path, columns: int) -> Path:
    """Tile the captures into one labelled sheet, so a sweep is one look."""
    run(
        "montage",
        *[str(path) for path in images],
        "-label",
        "%f",
        "-tile",
        f"{columns}x",
        "-geometry",
        "+4+4",
        "-background",
        "#101010",
        "-fill",
        "white",
        "-pointsize",
        "16",
        str(destination),
    )
    return destination


def _wait_ready(write_dir: Path, proc: subprocess.Popen[bytes], timeout_s: float = 180.0) -> None:
    """Wait until the engine is up *and* the dev scene has framed its camera.

    The only clock-based polling left in the sweep, and unavoidable: the control
    socket does not exist until the engine has booted far enough to open it. It
    waits on log markers rather than a duration, so it is not a guessed sleep.
    """
    log = write_dir / "infolog.txt"
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise RuntimeError(f"engine exited early with code {proc.returncode}")
        if log.is_file():
            text = log.read_text(errors="replace")
            if GAVE_UP_MARKER in text:
                raise RuntimeError(
                    f"the dev scene could not frame the camera, so every capture would be the whole-map view; see {log}"
                )
            if READY_MARKER in text and FRAMED_MARKER in text:
                return
        time.sleep(0.5)
    raise TimeoutError(f"editor did not become ready; see {log}")
