import json
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import TYPE_CHECKING, cast

from smoke.engine import prepare

from .paths import GAME_DIRNAME
from .run_state import RunState
from .x11 import find_windows, spring_processes, window_pid

if TYPE_CHECKING:
    from .runner import E2ERun


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
        self.screenshot("00-initial")

    def run_scenario(self) -> None:
        from .scenarios import run_scenario

        run_scenario(cast("E2ERun", self))

    def finish(self, status: str, **extra: object) -> None:
        self.collect_logs()
        self.event("finish", status=status, **extra)
        self.write_run_md(status, **extra)

    def stop(self) -> None:
        if self.proc is None or self.proc.poll() is not None:
            self.close_process_logs()
            return
        self.proc.terminate()
        try:
            self.proc.wait(timeout=4)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=4)
        self.close_process_logs()

    def wait_for_window(self, timeout_s: float = 45.0) -> str:
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
                        self.event("window", window=window_id, pid=pid)
                        return window_id
            self.assert_running()
            time.sleep(0.25)
        raise RuntimeError(
            f"no matching Recoil/Spring window found; last ids={last_ids}; spring processes={last_pid_map}"
        )

    def wait_for_ui_ready(self, timeout_s: float = 45.0) -> None:
        assert self.write_dir is not None
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
                    self.event("ui_ready", log=str(log_path), matched=matched)
                    return
            self.assert_running()
            time.sleep(0.25)
        self.event("ui_ready_timeout", logs=[str(path) for path in log_paths], timeout_s=timeout_s)
        raise RuntimeError(f"editor UI did not become ready within {timeout_s:.0f}s")

    def wait_for_ui_settle(self) -> None:
        time.sleep(0.4)

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

    def assert_running(self) -> None:
        if self.proc is not None and self.proc.poll() is not None:
            raise RuntimeError(f"engine exited early with code {self.proc.returncode}")

    def require_window(self) -> None:
        if not self.window:
            raise RuntimeError("window not available")
