from pathlib import Path
from time import monotonic
from typing import override

from control import Control, connect_session

from .state import RunState
from .timing import FAST, Timeout
from .utils.screenshots import Screenshot


class ControlMixin(RunState):
    """The control channel as a scenario-facing handle.

    The connection opens on first use and closes with the run, so a scenario
    that never asks for it costs nothing.
    """

    @property
    @override
    def control(self) -> Control:
        if self._control is None:
            assert self.write_dir is not None
            self._control = connect_session(self.write_dir, Timeout.UI_START)
            self.event("control_connected", instance_id=self._control.instance_id)
        return self._control

    @override
    def close_control(self) -> None:
        if self._control is not None:
            self._control.close()
            self._control = None

    @override
    def control_capture(self, name: str) -> Path:
        """Capture through the channel: no window handle, no cursor parking, and
        the image already contains every call made before it."""
        if FAST:
            self.event("control_capture_skipped", name=name)
            return self.screenshot_dir / f"{name}.png"
        stem = f"{len(self.screenshots):02d}-{name}"
        shot = Screenshot(
            name=name,
            bmp_path=self.screenshot_dir / f"{stem}.bmp",
            png_path=self.screenshot_dir / f"{stem}.png",
            crop=self.case.crop,
        )
        started = monotonic()
        self.control.capture(shot.bmp_path)
        self.screenshots.append(shot)
        self.screenshot_worker.submit(shot)
        self.event(
            "control_capture",
            name=name,
            path=str(shot.png_path),
            elapsed_ms=int((monotonic() - started) * 1000),
        )
        return shot.png_path
