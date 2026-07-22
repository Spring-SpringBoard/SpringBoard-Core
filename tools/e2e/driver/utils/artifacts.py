from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class RunArtifacts:
    root: Path

    @property
    def screenshots(self) -> Path:
        return self.root / "screens"

    @property
    def report(self) -> Path:
        return self.root / "run.md"

    @property
    def events(self) -> Path:
        return self.root / "events.jsonl"

    @property
    def port_flags(self) -> Path:
        return self.root / "port_flags.json"

    @property
    def infolog(self) -> Path:
        return self.root / "infolog.txt"

    @property
    def commands(self) -> Path:
        return self.root / "commands.jsonl"

    @property
    def engine_stdout(self) -> Path:
        return self.root / "engine.stdout.log"

    @property
    def engine_stderr(self) -> Path:
        return self.root / "engine.stderr.log"

    @property
    def files(self) -> tuple[Path, ...]:
        return (
            self.events,
            self.port_flags,
            self.infolog,
            self.commands,
            self.engine_stdout,
            self.engine_stderr,
        )
