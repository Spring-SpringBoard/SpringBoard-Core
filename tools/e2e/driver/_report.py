import json
import time
from pathlib import Path
from typing import override

from .state import RunState

INPUT_EVENT_KINDS = frozenset(
    {
        "click",
        "click_root",
        "click_settled",
        "drag",
        "drag_root",
        "key",
        "key_chord",
        "move",
        "move_relative",
        "press",
        "release",
        "type",
        "wheel",
        "wheel_root",
    }
)


def artifact_link(path: Path, root: Path, label: str | None = None) -> str:
    """Render a local artifact as a link relative to the report directory."""
    target = path.relative_to(root).as_posix()
    return f"[{label or path.name}]({target})"


class ReportMixin(RunState):
    @override
    def write_run_md(self, status: str, **extra: object) -> None:
        lines = [
            f"# UI E2E Run `{self.run_id}`",
            "",
            f"- status: `{status}`",
            f"- case: `{self.case.name}`",
            f"- scenario: `{self.case.scenario}`",
            f"- flags: `{json.dumps(self.case.flags, sort_keys=True)}`",
            f"- session: `{'isolated' if self.case.isolated else 'shared'}`",
            f"- reset: `{'none' if self.case.isolated else 'undo-reload'}`",
            f"- artifacts: `{self.out_dir}`",
        ]
        if self.write_dir is not None:
            lines.append(f"- write dir: `{self.write_dir}`")
            lines.append(f"- infolog: {artifact_link(self.artifacts.infolog, self.out_dir)}")
        if self.command is not None:
            lines.append(f"- command: `{' '.join(self.command)}`")
        if extra:
            lines.append(f"- notes: `{json.dumps(extra, sort_keys=True)}`")
        lines += ["", "## Screenshots", ""]
        if self.screenshots:
            for shot in self.screenshots:
                lines += [f"### {shot.png_path.stem}", ""]
                if shot.png_path.is_file():
                    rel = shot.png_path.relative_to(self.out_dir)
                    lines += [f"![]({rel})", ""]
        else:
            lines.append("_No screenshots yet._")
        files = [f"- {artifact_link(path, self.out_dir)}" for path in self.artifacts.files if path.is_file()]
        lines += ["", "## Files", "", *files]
        self.run_md.write_text("\n".join(lines) + "\n")

    @override
    def event(self, kind: str, **data: object) -> None:
        if kind in INPUT_EVENT_KINDS:
            self._input_pending = True
        payload = {"time": time.time(), "kind": kind, **data}
        with self.events_path.open("a") as f:
            f.write(json.dumps(payload, sort_keys=True) + "\n")
