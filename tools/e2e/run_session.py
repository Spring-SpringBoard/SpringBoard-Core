from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from paths import GAME_DIRNAME, TOOLS_SMOKE
from process import run
from x11 import find_windows, spring_processes, window_pid

sys.path.insert(0, str(TOOLS_SMOKE))
from run_sbc import prepare  # noqa: E402


class SessionMixin:
    """The engine process's lifecycle: bring it up, wait until its UI is live,
    tear it down, and gather what it left behind.

    Booting is a sequence of waits, each of which also checks the process is
    still alive so a crash fails fast with the exit code rather than timing out.
    """

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
        env.update(self.case.env)
        self.write_dir = write_dir
        self.command = cmd
        game_dir = write_dir / "games" / GAME_DIRNAME
        flags_path = game_dir / "port_flags.json"
        flags_path.write_text(json.dumps(self.case.flags, indent=2) + "\n")
        shutil.copyfile(flags_path, self.out_dir / "port_flags.json")
        self.event("launch", write_dir=str(write_dir), command=cmd, flags=self.case.flags)
        self.stdout_file = (self.out_dir / "engine.stdout.log").open("w")
        self.stderr_file = (self.out_dir / "engine.stderr.log").open("w")
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
        from scenarios import run_scenario

        run_scenario(self)

    def finish(self, status: str, **extra: object) -> None:
        if self.review_images:
            self.finish_conversions()
            self.generate_contact_sheet()
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
            f"no matching Recoil/Spring window found; last ids={last_ids}; "
            f"spring processes={last_pid_map}"
        )

    def wait_for_ui_ready(self, timeout_s: float = 45.0) -> None:
        assert self.write_dir is not None
        log_paths = (
            self.write_dir / "infolog.txt",
            self.out_dir / "engine.stdout.log",
            self.out_dir / "engine.stderr.log",
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
        for name in ("infolog.txt", "commands.jsonl"):
            src = self.write_dir / name
            if src.is_file():
                shutil.copyfile(src, self.out_dir / name)

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
        if self.window is None:
            raise RuntimeError("window not available")
