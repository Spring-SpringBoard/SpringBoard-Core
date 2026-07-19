from __future__ import annotations

import concurrent.futures
import subprocess
from datetime import datetime
from pathlib import Path

from cases import Case
from paths import ARTIFACT_ROOT
from run_capture import CaptureMixin
from run_commands import CommandLogMixin
from run_env import FAST, PANEL_TOLERANCE, SETTLE, command_fields, nap
from run_input import InputMixin
from run_pixels import PixelMixin
from run_report import ReportMixin
from run_session import SessionMixin
from screenshots import Screenshot

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
    """One scenario run against a live engine.

    The behaviour is split across mixins by concern -- session lifecycle, input,
    capture, pixel measurement, command-log assertions, reporting -- but they
    share the single instance state set up here, and a scenario drives them all
    through the one `run` object.
    """

    def __init__(
        self,
        case: Case,
        *,
        capture: str,
        review_images: bool,
        image_workers: int,
        update_golden: bool = False,
        stage_goldens: bool = False,
    ):
        self.case = case
        self.capture = capture
        self.update_golden = update_golden
        self.stage_goldens = stage_goldens
        self.golden_results: list[tuple[str, str]] = []
        self.review_images = review_images
        self.image_workers = image_workers
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.run_id = f"{stamp}-{case.name}"
        self.out_dir = ARTIFACT_ROOT / self.run_id
        self.screenshot_dir = self.out_dir / "screens"
        self.run_md = self.out_dir / "run.md"
        self.events_path = self.out_dir / "events.jsonl"
        self.write_dir: Path | None = None
        self.proc: subprocess.Popen[str] | None = None
        self.window: str | None = None
        self.command: list[str] | None = None
        self.stdout_file = None
        self.stderr_file = None
        self.screenshots: list[Screenshot] = []
        self.contact_sheet: Path | None = None
        self.image_pool: concurrent.futures.ThreadPoolExecutor | None = None
        self.image_futures: list[concurrent.futures.Future[tuple[Screenshot, int]]] = []
        self.out_dir.mkdir(parents=True, exist_ok=True)
        self.screenshot_dir.mkdir(parents=True, exist_ok=True)
        if self.review_images and self.capture == "raw":
            self.image_pool = concurrent.futures.ThreadPoolExecutor(
                max_workers=self.image_workers,
                thread_name_prefix="ui-e2e-image",
            )
        self.write_run_md("starting")
