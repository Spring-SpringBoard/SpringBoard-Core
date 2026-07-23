import subprocess
from abc import ABC, abstractmethod
from collections.abc import Callable
from contextlib import AbstractContextManager
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import TYPE_CHECKING, TextIO

from .timing import Delay, Timeout
from .utils.artifacts import RunArtifacts
from .utils.models import CommandData, CommandEntry, CommandValue
from .utils.paths import ARTIFACT_ROOT
from .utils.screenshots import Screenshot, ScreenshotConversion, ScreenshotWorker

if TYPE_CHECKING:
    from .cases import Case
else:
    Case = object


@dataclass(frozen=True, slots=True)
class GoldenCheck:
    name: str
    path: Path
    tolerance: int
    capture_ms: int


@dataclass(frozen=True, slots=True)
class PixelCheck:
    before: Path
    after: Path
    region: tuple[int, int, int, int] | None
    min_changed: int
    max_changed: int | None


@dataclass
class RunState(ABC):
    case: Case
    update_golden: bool = False
    stage_goldens: bool = False
    golden_results: list[tuple[str, str]] = field(default_factory=list[tuple[str, str]], init=False)
    pending_goldens: list[GoldenCheck] = field(default_factory=list[GoldenCheck], init=False)
    pending_pixel_checks: list[PixelCheck] = field(default_factory=list[PixelCheck], init=False)
    run_id: str = field(init=False)
    artifacts: RunArtifacts = field(init=False)
    write_dir: Path | None = field(default=None, init=False)
    proc: subprocess.Popen[str] | None = field(default=None, init=False)
    window: str = field(default="", init=False)
    command: list[str] | None = field(default=None, init=False)
    stdout_file: TextIO | None = field(default=None, init=False)
    stderr_file: TextIO | None = field(default=None, init=False)
    screenshots: list[Screenshot] = field(default_factory=list[Screenshot], init=False)
    screenshot_worker: ScreenshotWorker = field(init=False)

    def __post_init__(self) -> None:
        stamp = datetime.now(UTC).strftime("%Y%m%d-%H%M%S")
        self.run_id = f"{stamp}-{self.case.name}"
        self.artifacts = RunArtifacts(ARTIFACT_ROOT / self.run_id)
        self.out_dir.mkdir(parents=True, exist_ok=True)
        self.screenshot_dir.mkdir(parents=True, exist_ok=True)
        self.screenshot_worker = ScreenshotWorker()

    @property
    def out_dir(self) -> Path:
        return self.artifacts.root

    @property
    def screenshot_dir(self) -> Path:
        return self.artifacts.screenshots

    @property
    def run_md(self) -> Path:
        return self.artifacts.report

    @property
    def events_path(self) -> Path:
        return self.artifacts.events

    @abstractmethod
    def assert_running(self) -> None: ...

    @abstractmethod
    def assert_any_command(
        self,
        class_name: str,
        **expected: CommandValue | Callable[[CommandValue], bool],
    ) -> CommandData: ...

    @abstractmethod
    def assert_command(
        self,
        class_name: str,
        **expected: CommandValue | Callable[[CommandValue], bool],
    ) -> CommandData: ...

    @abstractmethod
    def assert_command_at_least(self, class_name: str, count: int) -> int: ...

    @abstractmethod
    def assert_command_count(self, class_name: str, count: int) -> None: ...

    @abstractmethod
    def assert_no_command_after(
        self, marker: CommandData, class_name: str, **expected: CommandValue | Callable[[CommandValue], bool]
    ) -> None: ...

    @abstractmethod
    def assert_region_pixels(
        self,
        before: Path,
        after: Path,
        region: tuple[int, int, int, int],
        *,
        min_changed: int = 0,
        max_changed: int | None = None,
    ) -> None: ...

    @abstractmethod
    def assert_screenshot_pixels(
        self, before: Path, after: Path, *, min_changed: int = 0, max_changed: int | None = None
    ) -> None: ...

    @abstractmethod
    def click(self, x: int, y: int, button: int = 1, delay: Delay = Delay.INPUT) -> None: ...

    @abstractmethod
    def click_root(self, x: int, y: int, button: int = 1, delay: Delay = Delay.INPUT) -> None: ...

    @abstractmethod
    def click_settled(self, x: int, y: int, button: int = 1, delay: Delay = Delay.INPUT) -> None: ...

    @abstractmethod
    def clipboard(self) -> str: ...

    @abstractmethod
    def command_cursor(self) -> int: ...

    @abstractmethod
    def commands(self) -> list[CommandEntry]: ...

    @abstractmethod
    def count_color(
        self, shot: Path, region: tuple[int, int, int, int], color: str = "#00FF00", fuzz: str = "12%"
    ) -> int: ...

    @abstractmethod
    def drag(
        self,
        x1: int,
        y1: int,
        x2: int,
        y2: int,
        button: int = 1,
        steps: int = 12,
        step_delay: Delay = Delay.EVENT,
    ) -> None: ...

    @abstractmethod
    def event(self, kind: str, **data: object) -> None: ...

    @abstractmethod
    def engine_log(self) -> list[str]: ...

    @abstractmethod
    def fill_text(
        self,
        x: int,
        y: int,
        text: str,
        *,
        click_delay: Delay = Delay.CONTROL,
        commit_delay: Delay = Delay.SETTLE,
    ) -> None: ...

    @abstractmethod
    def focus(self) -> None: ...

    @abstractmethod
    def golden(self, name: str, crop: str | None = "<case>", tolerance: int = 20, park: bool = True) -> Path: ...

    @abstractmethod
    def key(self, name: str, delay: Delay = Delay.INPUT) -> None: ...

    @abstractmethod
    def key_chord(self, modifiers: tuple[str, ...], name: str, delay: Delay = Delay.INPUT) -> None: ...

    @abstractmethod
    def log_cursor(self) -> int: ...

    @abstractmethod
    def move(self, x: int, y: int, delay: Delay = Delay.INPUT) -> None: ...

    @abstractmethod
    def move_relative(self, dx: int, dy: int = 0, steps: int = 6, delay: Delay = Delay.INPUT) -> None: ...

    @abstractmethod
    def modifier(self, name: str) -> AbstractContextManager[None]: ...

    @abstractmethod
    def press(self, x: int, y: int, button: int = 1, delay: Delay = Delay.CONTROL) -> None: ...

    @abstractmethod
    def release(self, x: int, y: int, button: int = 1, delay: Delay = Delay.FRAME) -> None: ...

    @abstractmethod
    def require_window(self) -> None: ...

    @abstractmethod
    def screenshot(self, name: str) -> Path: ...

    @abstractmethod
    def screenshot_root(self, name: str) -> Path: ...

    @abstractmethod
    def set_clipboard(self, text: str) -> None: ...

    @abstractmethod
    def type_text(self, text: str, delay_ms: int = 10) -> None: ...

    @abstractmethod
    def wait_for_command(
        self,
        class_name: str,
        *,
        after: int = 0,
        timeout_s: Timeout = Timeout.COMMAND,
        **expected: CommandValue | Callable[[CommandValue], bool],
    ) -> CommandData: ...

    @abstractmethod
    def wait_for_log(self, text: str, *, after: int = 0, timeout_s: Timeout = Timeout.LOG) -> str: ...

    @abstractmethod
    def wheel(self, x: int, y: int, clicks: int = 1, up: bool = True, delay: Delay = Delay.FRAME) -> None: ...

    @abstractmethod
    def wheel_root(self, x: int, y: int, clicks: int = 1, up: bool = True, delay: Delay = Delay.FRAME) -> None: ...

    @abstractmethod
    def write_run_md(self, status: str, **extra: object) -> None: ...

    @abstractmethod
    def _finish_screenshots(self) -> list[str]: ...

    @abstractmethod
    def _finish_pixel_assertions(self) -> list[str]: ...

    @abstractmethod
    def _wait_for_screenshot(self, path: Path) -> ScreenshotConversion: ...
