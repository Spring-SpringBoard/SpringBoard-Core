import json
import time
from typing import override

from .state import RunState


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
            f"- artifacts: `{self.out_dir}`",
        ]
        if self.write_dir is not None:
            lines.append(f"- write dir: `{self.write_dir}`")
            lines.append(f"- infolog: `{self.write_dir / 'infolog.txt'}`")
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
        files = [f"- `{path.name}`" for path in self.artifacts.files if path.is_file()]
        lines += ["", "## Files", "", *files]
        self.run_md.write_text("\n".join(lines) + "\n")

    @override
    def event(self, kind: str, **data: object) -> None:
        payload = {"time": time.time(), "kind": kind, **data}
        with self.events_path.open("a") as f:
            f.write(json.dumps(payload, sort_keys=True) + "\n")
