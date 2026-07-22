from .driver._capture import CaptureMixin
from .driver._commands import CommandLogMixin
from .driver._input import InputMixin
from .driver._pixels import PixelMixin
from .driver._report import ReportMixin
from .driver._session import SessionMixin
from .driver.state import RunState
from .driver.utils.run_env import FAST, PANEL_TOLERANCE, SETTLE, command_fields, nap

# Re-exported for callers that still reach for them via `runner`.
__all__ = ["FAST", "PANEL_TOLERANCE", "SETTLE", "E2ERun", "command_fields", "nap"]


class E2ERun(
    SessionMixin,
    InputMixin,
    CaptureMixin,
    PixelMixin,
    CommandLogMixin,
    ReportMixin,
    RunState,
):
    def __post_init__(self) -> None:
        super().__post_init__()
        self.write_run_md("starting")
