from __future__ import annotations

import json
import time


class ReportMixin:
    """The run's human-readable report and its machine-readable event log.

    `event` appends one JSON line per step to `events.jsonl` -- the trace a
    failure is explained from afterwards. `write_run_md` renders `run.md`, the
    artifact a human opens: status, the flags in play, and every screenshot
    inline.
    """

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
        if self.contact_sheet is not None:
            lines += ["### Contact Sheet", "", "![](contact-sheet.png)", ""]
        if self.screenshots:
            for shot in self.screenshots:
                lines += [f"### {shot.png_path.stem}", ""]
                if shot.png_path.is_file():
                    rel = shot.png_path.relative_to(self.out_dir)
                    lines += [f"![]({rel})", ""]
                else:
                    rel = shot.raw_path.relative_to(self.out_dir)
                    lines += [f"- raw capture: `{rel}`", ""]
        else:
            lines.append("_No screenshots yet._")
        lines += [
            "",
            "## Files",
            "",
            "- `events.jsonl`",
            "- `port_flags.json`",
        ]
        if (self.out_dir / "infolog.txt").is_file():
            lines.append("- `infolog.txt`")
        if (self.out_dir / "commands.jsonl").is_file():
            lines.append("- `commands.jsonl`")
        if (self.out_dir / "engine.stdout.log").is_file():
            lines.append("- `engine.stdout.log`")
        if (self.out_dir / "engine.stderr.log").is_file():
            lines.append("- `engine.stderr.log`")
        self.run_md.write_text("\n".join(lines) + "\n")

    def event(self, kind: str, **data: object) -> None:
        payload = {"time": time.time(), "kind": kind, **data}
        with self.events_path.open("a") as f:
            f.write(json.dumps(payload, sort_keys=True) + "\n")
