import subprocess
from datetime import datetime
from pathlib import Path

from .artifacts import RunArtifacts
from .cases import Case
from .paths import ARTIFACT_ROOT
from .run_capture import CaptureMixin
from .run_commands import CommandLogMixin
from .run_env import FAST, PANEL_TOLERANCE, SETTLE, command_fields, nap
from .run_input import InputMixin
from .run_pixels import PixelMixin
from .run_report import ReportMixin
from .run_session import SessionMixin
from .screenshots import Screenshot

# Re-exported for callers that still reach for them via `runner`.
__all__ = ["E2ERun", "FAST", "PANEL_TOLERANCE", "SETTLE", "command_fields", "nap"]


class E2ERun(
    SessionMixin,
    InputMixin,
    CaptureMixin,
    PixelMixin,
    CommandLogMixin,
    ReportMixin,
):
    def __init__(
        self,
        case: Case,
        *,
        update_golden: bool = False,
        stage_goldens: bool = False,
    ):
        self.case = case
        self.update_golden = update_golden
        self.stage_goldens = stage_goldens
        self.golden_results: list[tuple[str, str]] = []
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.run_id = f"{stamp}-{case.name}"
        self.out_dir = ARTIFACT_ROOT / self.run_id
        self.artifacts = RunArtifacts(self.out_dir)
        self.screenshot_dir = self.artifacts.screenshots
        self.run_md = self.artifacts.report
        self.events_path = self.artifacts.events
        self.write_dir: Path | None = None
        self.proc: subprocess.Popen[str] | None = None
        self.window = ""
        self.command: list[str] | None = None
        self.stdout_file = None
        self.stderr_file = None
        self.screenshots: list[Screenshot] = []
        self.out_dir.mkdir(parents=True, exist_ok=True)
        self.screenshot_dir.mkdir(parents=True, exist_ok=True)
        self.write_run_md("starting")
