import json
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import TYPE_CHECKING, cast, override

from smoke.engine import prepare

from .state import RunState
from .timing import Delay, Timeout, pause
from .utils.paths import GAME_DIRNAME
from .utils.x11 import find_windows, spring_processes, window_pid

if TYPE_CHECKING:
    from e2e.runner import E2ERun


RML_DIAGNOSTIC = re.compile(r"(?:Warning|Error): \[RmlUi\]")


def rml_diagnostics(lines: list[str]) -> list[str]:
    """The RmlUi diagnostics that make an E2E invalid even if its final
    command or pixels happen to look plausible."""
    return [line for line in lines if RML_DIAGNOSTIC.search(line)]


class SessionMixin(RunState):
    def launch(self) -> None:
        write_dir, env, cmd = prepare(prefix="sbc-ui-e2e-")
        # Two things move on their own and would make every capture unrepeatable:
        # the def thumbnails spin, and the dev console prints whatever the engine
        # feels like saying (timestamps, ids). Hold the models still and start the
        # console hidden -- a scenario that wants it presses F8.
        env["SBC_STILL_MODELS"] = "1"
        env["SBC_HIDE_CONSOLE"] = "1"
        # Run every E2E with field and map tooltips enabled. A scenario parks the
        # pointer before a stable golden when it is not testing a tooltip; this
        # way every interaction also exercises the native/Lua tooltip paths.
        env["SBC_HIDE_TOOLTIPS"] = "0"
        # Debug lines land in the run's infolog, so a failure can be explained
        # afterwards from the artifact rather than by re-running with printfs.
        env["SBC_LOG_LEVEL"] = "debug"
        env["SBC_E2E_SCREENSHOT_REQUEST"] = str(write_dir / "e2e-screenshot-request.txt")
        # The control channel writes its discovery file here; a scenario that
        # never touches `run_state.control` simply leaves the socket idle.
        env["SBC_CONTROL_FILE"] = str(write_dir / "control.json")
        env.update(self.case.env)
        self.write_dir = write_dir
        self.command = cmd
        game_dir = write_dir / "games" / GAME_DIRNAME
        flags_path = game_dir / self.artifacts.port_flags.name
        flags_path.write_text(json.dumps(self.case.flags, indent=2) + "\n")
        shutil.copyfile(flags_path, self.artifacts.port_flags)
        self.event("launch", write_dir=str(write_dir), command=cmd, flags=self.case.flags)
        self.stdout_file = self.artifacts.engine_stdout.open("w")
        self.stderr_file = self.artifacts.engine_stderr.open("w")
        self.proc = subprocess.Popen(
            cmd,
            env=env,
            text=True,
            stdout=self.stdout_file,
            stderr=self.stderr_file,
        )
        self.window = self.wait_for_window()
        self.focus()
        self.wait_for_ui_ready()
        self.wait_for_ui_settle()
        self.assert_no_rml_diagnostics()
        self.screenshot("00-initial")

    def run_scenario(self) -> None:
        from ._scenarios import run_scenario

        run_scenario(cast("E2ERun", self))

    def finish(self, status: str, **extra: object) -> None:
        failures = [*self._finish_screenshots(), *self._finish_pixel_assertions()]
        self.assert_no_rml_diagnostics()
        if failures:
            status = "failed"
            extra = {**extra, "assertion_failures": failures}
        self.collect_logs()
        self.event("finish", status=status, **extra)
        self.write_run_md(status, **extra)
        if failures:
            raise AssertionError("E2E assertions failed:\n" + "\n".join(failures))

    def stop(self) -> None:
        self.close_control()
        if self.proc is None or self.proc.poll() is not None:
            self.close_process_logs()
            return
        self.proc.terminate()
        try:
            self.proc.wait(timeout=Timeout.SHUTDOWN)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=Timeout.SHUTDOWN)
        self.close_process_logs()

    def wait_for_window(self, timeout_s: Timeout = Timeout.UI_START) -> str:
        started = time.monotonic()
        deadline = time.monotonic() + timeout_s
        last_ids: list[str] = []
        last_pid_map: dict[int, str] = {}
        while time.monotonic() < deadline:
            ids = find_windows()
            if ids:
                last_ids = ids
                pid_map = spring_processes()
                last_pid_map = pid_map
                for window_id in reversed(ids):
                    pid = window_pid(window_id)
                    if pid in pid_map and self.write_dir and str(self.write_dir) in pid_map[pid]:
                        self.event(
                            "window",
                            window=window_id,
                            pid=pid,
                            wait_ms=int((time.monotonic() - started) * 1000),
                        )
                        return window_id
            self.assert_running()
            pause(Delay.FRAME)
        raise RuntimeError(
            f"no matching Recoil/Spring window found; last ids={last_ids}; spring processes={last_pid_map}"
        )

    def wait_for_ui_ready(self, timeout_s: Timeout = Timeout.UI_START) -> None:
        assert self.write_dir is not None
        started = time.monotonic()
        log_paths = (
            self.write_dir / "infolog.txt",
            self.artifacts.engine_stdout,
            self.artifacts.engine_stderr,
        )
        deadline = time.monotonic() + timeout_s
        patterns = (
            "finished loading and is now ingame",
            "Sim/frame",
        )
        while time.monotonic() < deadline:
            for log_path in log_paths:
                if not log_path.is_file():
                    continue
                text = log_path.read_text(errors="replace")
                matched = next((pattern for pattern in patterns if pattern in text), None)
                if matched is not None:
                    self.event(
                        "ui_ready",
                        log=str(log_path),
                        matched=matched,
                        wait_ms=int((time.monotonic() - started) * 1000),
                    )
                    return
            self.assert_running()
            pause(Delay.FRAME)
        self.event("ui_ready_timeout", logs=[str(path) for path in log_paths], timeout_s=timeout_s)
        raise RuntimeError(f"editor UI did not become ready within {timeout_s:.0f}s")

    def wait_for_ui_settle(self) -> None:
        started = time.monotonic()
        pause(Delay.SETTLE)
        self.event("ui_settled", elapsed_ms=int((time.monotonic() - started) * 1000))

    def assert_no_rml_diagnostics(self) -> None:
        """Fail on new RmlUi warnings/errors as soon as a harness boundary is
        reached, rather than burying them in a copied infolog artifact."""
        assert self.write_dir is not None
        path = self.write_dir / "infolog.txt"
        if not path.is_file():
            return
        lines = path.read_text(errors="replace").splitlines()
        diagnostics = rml_diagnostics(lines[self._rml_diagnostic_cursor :])
        self._rml_diagnostic_cursor = len(lines)
        if diagnostics:
            shown = diagnostics[:8]
            self.event("rml_diagnostics", count=len(diagnostics), lines=shown)
            raise AssertionError(
                "RmlUi emitted diagnostics:\n" + "\n".join(shown)
            )

    def cleanup_write_dir(self) -> None:
        # Each run gets a fresh temp write dir holding a full copy of the game
        # (~hundreds of MB). They were never removed, which filled the disk.
        # Logs have already been copied into the run's artifact dir by
        # collect_logs(), so nothing here is needed afterwards.
        write_dir = self.write_dir
        if write_dir is None:
            return
        resolved = write_dir.resolve()
        if resolved.parent != Path(tempfile.gettempdir()).resolve():
            return
        if not resolved.name.startswith("sbc-"):
            return
        shutil.rmtree(resolved, ignore_errors=True)
        self.write_dir = None

    def collect_logs(self) -> None:
        if self.write_dir is None:
            return
        for destination in (self.artifacts.infolog, self.artifacts.commands):
            src = self.write_dir / destination.name
            if src.is_file():
                shutil.copyfile(src, destination)

    def close_process_logs(self) -> None:
        for handle_name in ("stdout_file", "stderr_file"):
            handle = getattr(self, handle_name)
            if handle is not None:
                handle.close()
                setattr(self, handle_name, None)

    @override
    def assert_running(self) -> None:
        if self.proc is not None and self.proc.poll() is not None:
            raise RuntimeError(f"engine exited early with code {self.proc.returncode}")

    @override
    def require_window(self) -> None:
        if not self.window:
            raise RuntimeError("window not available")
