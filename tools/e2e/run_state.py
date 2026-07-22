import subprocess
from pathlib import Path
from typing import TYPE_CHECKING, Protocol

from .artifacts import RunArtifacts
from .screenshots import Screenshot

if TYPE_CHECKING:
    from .cases import Case
else:
    Case = object


class RunState(Protocol):
    case: Case
    update_golden: bool
    stage_goldens: bool
    golden_results: list[tuple[str, str]]
    run_id: str
    out_dir: Path
    artifacts: RunArtifacts
    screenshot_dir: Path
    run_md: Path
    events_path: Path
    write_dir: Path | None
    proc: subprocess.Popen[str] | None
    window: str
    command: list[str] | None
    screenshots: list[Screenshot]

    def assert_running(self) -> None: ...
    def event(self, kind: str, **data: object) -> None: ...
    def fill_text(self, x: int, y: int, text: str, *, click_delay: float = 0.2, commit_delay: float = 0.35) -> None: ...
    def focus(self) -> None: ...
    def require_window(self) -> None: ...
    def screenshot(self, name: str) -> Path: ...
    def write_run_md(self, status: str, **extra: object) -> None: ...
