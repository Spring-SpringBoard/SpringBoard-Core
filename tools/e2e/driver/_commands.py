import json
import time
from collections.abc import Callable
from typing import override

from .state import RunState
from .timing import Delay, Timeout, pause
from .utils.models import CommandData, CommandEntry, CommandValue, parse_command_entry
from .utils.run_env import command_fields


class CommandLogMixin(RunState):
    """Reading the run's logs and asserting on what the UI actually did.

    Two sources: `commands.jsonl`, the envelopes the UI sent to the command
    bridge, and the engine's `infolog.txt`, where the plugin narrates behaviour
    that never reaches the bridge. The assertions distinguish committed commands
    from previews -- a live drag emits a stream of previews that never enter the
    undo history -- because a scenario almost always means the committed one.
    """

    @override
    def engine_log(self) -> list[str]:
        """The engine's infolog for this run, a line at a time.

        The plugin logs what it did (a gallery control reporting its value, a
        state reporting its angle), so a scenario can assert on behaviour that
        never reaches the command bridge.
        """
        assert self.write_dir is not None
        path = self.write_dir / "infolog.txt"
        if not path.is_file():
            return []
        return path.read_text(errors="replace").splitlines()

    @override
    def log_cursor(self) -> int:
        """A position in the engine log that can be passed to ``wait_for_log``.

        Reloading a project starts a new game in the same process, so its ready
        line occurs more than once.  Capturing a cursor lets a scenario wait
        for the *next* occurrence instead of sleeping for a guessed duration.
        """
        return len(self.engine_log())

    @override
    def wait_for_log(self, text: str, *, after: int = 0, timeout_s: Timeout = Timeout.LOG) -> str:
        """Wait until a newly written engine-log line contains ``text``.

        The process is checked on every poll, which turns a reload crash into a
        useful immediate error rather than an arbitrary timeout.
        """
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            for line in self.engine_log()[after:]:
                if text in line:
                    self.event("wait_for_log", text=text, line=line)
                    return line
            self.assert_running()
            pause(Delay.MS_50)
        raise AssertionError(f"timed out waiting {timeout_s:.1f}s for log line containing {text!r}")

    @override
    def wait_for_command(
        self,
        class_name: str,
        *,
        after: int = 0,
        timeout_s: Timeout = Timeout.COMMAND,
        **expected: CommandValue | Callable[[CommandValue], bool],
    ) -> CommandData:
        """Wait for a committed command, optionally matching fields.

        This is for asynchronous UI paths such as modal acceptance.  Unlike an
        assertion, it returns as soon as the command bridge records the event.
        """
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            for entry in self.commands()[after:]:
                data = entry["data"]
                if data.get("__preview") or data.get("className") != class_name:
                    continue
                fields = command_fields(data)
                if all(
                    key in fields and (want(fields[key]) if callable(want) else fields[key] == want)
                    for key, want in expected.items()
                ):
                    self.event("wait_for_command", className=class_name, keys=sorted(expected))
                    return data
            self.assert_running()
            pause(Delay.MS_50)
        raise AssertionError(f"timed out waiting {timeout_s:.1f}s for {class_name} with keys {sorted(expected)}")

    @override
    def commands(self) -> list[CommandEntry]:
        """Every command envelope the UI sent to the command bridge.

        A `CompoundCommand` is unwrapped into the commands it carries, and kept
        as well. The Lua UI groups a placement into one compound for undo while
        the native UI sends the command on its own, and a scenario should be able
        to assert the same thing of both.
        """
        assert self.write_dir is not None
        path = self.write_dir / "commands.jsonl"
        if not path.is_file():
            return []
        entries: list[CommandEntry] = []
        for line in path.read_text().splitlines():
            _stamp, _, payload = line.partition(" ")
            if not payload:
                continue
            entry = parse_command_entry(json.loads(payload))
            if entry is None:
                continue
            entries.append(entry)
            data = entry["data"]
            nested = data.get("commands")
            if data.get("className") == "CompoundCommand" and isinstance(nested, list):
                entries.extend({"data": inner} for inner in nested if isinstance(inner, dict))
        return entries

    @override
    def command_cursor(self) -> int:
        """A position in the command log for ``wait_for_command(after=...)``."""
        return len(self.commands())

    @override
    def assert_command(self, class_name: str, **expected: CommandValue | Callable[[CommandValue], bool]) -> CommandData:
        """Assert exactly one committed command of `class_name` carrying every
        key in `expected` was sent, and that those values match.

        A value may be a callable predicate, for things like a colour that is
        "red enough" rather than an exact float. Matching on the keys as well as
        the class lets one editor emit several commands of the same class.

        Previews (`__preview`) are excluded: they apply to the engine but never
        reach the undo history, and a drag emits a stream of them. Use
        `assert_previews` for those.
        """
        committed = [entry["data"] for entry in self.commands() if not entry["data"].get("__preview")]
        matches = [
            data
            for data in committed
            if data.get("className") == class_name
            and all(
                key in command_fields(data)
                and (want(command_fields(data)[key]) if callable(want) else command_fields(data)[key] == want)
                for key, want in expected.items()
            )
        ] or [data for data in committed if data.get("className") == class_name and not expected]
        if len(matches) != 1:
            sent = [
                (entry["data"].get("className"), sorted(command_fields(entry["data"]))) for entry in self.commands()
            ]
            raise AssertionError(
                f"expected exactly one {class_name} with keys {sorted(expected)}, got {len(matches)}. Sent: {sent}"
            )
        data = matches[0]
        self.event("assert_command", className=class_name, keys=sorted(expected))
        return data

    @override
    def assert_no_command_after(
        self, marker: CommandData, class_name: str, **expected: CommandValue | Callable[[CommandValue], bool]
    ) -> None:
        """Assert nothing more of this kind was sent after `marker`.

        For proving something *stopped*: a drag that was released must not keep
        emitting as the mouse moves on.
        """
        seen_marker = False
        for entry in self.commands():
            data = entry["data"]
            if data is marker or data.get("__cmd_id") == marker.get("__cmd_id"):
                seen_marker = True
                continue
            if not seen_marker or data.get("className") != class_name:
                continue
            fields = command_fields(data)
            if all(fields.get(key) == want for key, want in expected.items() if not callable(want)):
                raise AssertionError(f"{class_name} was still being sent after the drag ended: {fields}")

    @override
    def assert_command_count(self, class_name: str, count: int) -> None:
        """Assert exactly `count` committed commands of this class were sent.

        For things whose whole point is *how many*: placing with an amount of 5
        must emit five adds, not one.
        """
        sent = [
            entry["data"]
            for entry in self.commands()
            if entry["data"].get("className") == class_name and not entry["data"].get("__preview")
        ]
        if len(sent) != count:
            raise AssertionError(f"expected {count} committed {class_name}, got {len(sent)}")
        self.event("assert_command_count", className=class_name, count=count)

    @override
    def assert_command_at_least(self, class_name: str, count: int) -> int:
        """Assert at least `count` committed commands of this class were sent.

        A held brush stroke is a stream of dabs, not one: how many depends on how
        long the button was down, so the floor is what can be asserted.
        """
        sent = [
            entry["data"]
            for entry in self.commands()
            if entry["data"].get("className") == class_name and not entry["data"].get("__preview")
        ]
        if len(sent) < count:
            raise AssertionError(f"expected at least {count} committed {class_name}, got {len(sent)}")
        self.event("assert_command_at_least", className=class_name, count=len(sent))
        return len(sent)

    @override
    def assert_any_command(
        self, class_name: str, **expected: CommandValue | Callable[[CommandValue], bool]
    ) -> CommandData:
        """Assert at least one committed command matched `expected`.

        Brush scenarios often exercise several modes of the same command class;
        this keeps the assertion about the specific mode/property rather than
        requiring the scenario to isolate every click in a fresh process.
        """
        for entry in self.commands():
            data = entry["data"]
            if data.get("__preview") or data.get("className") != class_name:
                continue
            opts = command_fields(data)
            if all(key in opts for key in expected) and all(
                want(opts.get(key)) if callable(want) else opts.get(key) == want for key, want in expected.items()
            ):
                self.event("assert_any_command", className=class_name, keys=sorted(expected))
                return data
        sent = [
            (entry["data"].get("className"), sorted(command_fields(entry["data"])))
            for entry in self.commands()
            if entry["data"].get("className") == class_name
        ]
        raise AssertionError(f"expected at least one {class_name} matching {expected}, got {sent}")

    def assert_previews(self, class_name: str, **expected: CommandValue | Callable[[CommandValue], bool]) -> int:
        """Assert at least one *preview* of `class_name` matched `expected`.

        A live drag emits one per frame, so the count is timing-dependent; that
        any arrived, carrying the right value, is the deterministic part.
        """
        matches = [
            entry["data"]
            for entry in self.commands()
            if entry["data"].get("__preview")
            and entry["data"].get("className") == class_name
            and all(key in command_fields(entry["data"]) for key in expected)
        ]
        good: list[CommandData] = []
        for data in matches:
            opts = command_fields(data)
            if all(want(opts.get(key)) if callable(want) else opts.get(key) == want for key, want in expected.items()):
                good.append(data)
        if not good:
            raise AssertionError(
                f"expected at least one {class_name} preview matching "
                f"{sorted(expected)}, got {len(matches)} previews of that class"
            )
        self.event("assert_previews", className=class_name, count=len(good))
        return len(good)
