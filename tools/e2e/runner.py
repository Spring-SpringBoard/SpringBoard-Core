from .driver._capture import CaptureMixin
from .driver._commands import CommandLogMixin
from .driver._control import ControlMixin
from .driver._input import InputMixin
from .driver._pixels import PixelMixin
from .driver._report import ReportMixin
from .driver._session import SessionMixin
from .driver.state import RunState


class E2ERun(
    SessionMixin,
    InputMixin,
    CaptureMixin,
    PixelMixin,
    CommandLogMixin,
    ControlMixin,
    ReportMixin,
    RunState,
):
    def __post_init__(self) -> None:
        super().__post_init__()
        self.write_run_md("starting")
