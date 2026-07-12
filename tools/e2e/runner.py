from __future__ import annotations

import concurrent.futures
import json
from contextlib import contextmanager
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path

from cases import Case
from golden import GoldenMismatch, compare as compare_golden
from paths import ARTIFACT_ROOT, GAME_DIRNAME, TOOLS_SMOKE
from process import run
from screenshots import Screenshot, convert_screenshot_file
from x11 import find_windows, spring_processes, window_geometry, window_pid

sys.path.insert(0, str(TOOLS_SMOKE))
from run_sbc import prepare  # noqa: E402


# Distinguishes "no crop override" from an explicit `crop=None` (full frame).
_CASE_CROP = "<case>"

# Envelope bookkeeping, not command fields.
_ENVELOPE_KEYS = frozenset({"className", "__cmd_id", "__preview"})


def command_fields(data: dict) -> dict:
    """A command's fields, whichever envelope shape it used.

    There are two, and they are not interchangeable: `envelope()` nests the
    fields under `opts`, while `envelope_fields()` puts them flat on the command
    (SetObjectParamCommand, AddObjectCommand). Reading only `opts` makes a
    flat command look like it carries nothing at all.
    """
    if isinstance(data.get("opts"), dict):
        return data["opts"]
    return {key: value for key, value in data.items() if key not in _ENVELOPE_KEYS}

MODIFIERS = (
    "Control_L",
    "Control_R",
    "Shift_L",
    "Shift_R",
    "Alt_L",
    "Alt_R",
    "Super_L",
    "Super_R",
)
MODIFIER_NAMES = {
    "ctrl": "Control_L",
    "control": "Control_L",
    "shift": "Shift_L",
    "alt": "Alt_L",
}


class E2ERun:
    def __init__(
        self,
        case: Case,
        *,
        capture: str,
        review_images: bool,
        image_workers: int,
        update_golden: bool = False,
    ):
        self.case = case
        self.capture = capture
        self.update_golden = update_golden
        self.golden_results: list[tuple[str, str]] = []
        self.review_images = review_images
        self.image_workers = image_workers
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.run_id = f"{stamp}-{case.name}"
        self.out_dir = ARTIFACT_ROOT / self.run_id
        self.screenshot_dir = self.out_dir / "screens"
        self.run_md = self.out_dir / "run.md"
        self.events_path = self.out_dir / "events.jsonl"
        self.write_dir: Path | None = None
        self.proc: subprocess.Popen[str] | None = None
        self.window: str | None = None
        self.command: list[str] | None = None
        self.stdout_file = None
        self.stderr_file = None
        self.screenshots: list[Screenshot] = []
        self.contact_sheet: Path | None = None
        self.image_pool: concurrent.futures.ThreadPoolExecutor | None = None
        self.image_futures: list[concurrent.futures.Future[tuple[Screenshot, int]]] = []
        self.out_dir.mkdir(parents=True, exist_ok=True)
        self.screenshot_dir.mkdir(parents=True, exist_ok=True)
        if self.review_images and self.capture == "raw":
            self.image_pool = concurrent.futures.ThreadPoolExecutor(
                max_workers=self.image_workers,
                thread_name_prefix="ui-e2e-image",
            )
        self.write_run_md("starting")

    def launch(self) -> None:
        write_dir, env, cmd = prepare(prefix="sbc-ui-e2e-")
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

    def focus(self) -> None:
        self.require_window()
        run("xdotool", "windowactivate", self.window, "windowfocus", self.window)
        time.sleep(0.08)
        self.release_modifiers()
        self.event("focus", window=self.window)

    def release_modifiers(self) -> None:
        self.require_window()
        args = ["xdotool"]
        for modifier in MODIFIERS:
            args += ["keyup", "--window", self.window, modifier]
        run(*args, check=False)
        time.sleep(0.03)

    def key(self, name: str, delay: float = 0.06) -> None:
        self.require_window()
        self.event("key", key=name)
        if "+" in name:
            # `xdotool key --window <win> ctrl+c` delivers the `c` press with the
            # modifier already cleared, so the engine reports ctrl=false. Send the
            # chord to the focused window instead, holding the modifiers down.
            self.focus()
            *modifiers, base = name.split("+")
            for modifier in modifiers:
                run("xdotool", "keydown", modifier)
            run("xdotool", "key", base)
            for modifier in reversed(modifiers):
                run("xdotool", "keyup", modifier)
        else:
            run("xdotool", "key", "--window", self.window, name)
        time.sleep(delay)

    @contextmanager
    def modifier(self, name: str):
        """Hold a modifier down across other input, for a chord like Ctrl-drag.

        Sent to the focused window rather than with `--window`: as with `key`,
        `xdotool --window` delivers the event with the modifier already cleared,
        and the engine then reports the modifier as up.
        """
        self.focus()
        self.event("modifier_down", modifier=name)
        run("xdotool", "keydown", name)
        try:
            yield
        finally:
            run("xdotool", "keyup", name)
            self.event("modifier_up", modifier=name)

    def key_chord(self, modifiers: tuple[str, ...], name: str, delay: float = 0.08) -> None:
        self.require_window()
        normalized = tuple(MODIFIER_NAMES.get(mod, mod) for mod in modifiers)
        chord = "+".join((*normalized, name))
        self.event("key_chord", chord=chord)
        run("xdotool", "key", "--window", self.window, chord)
        time.sleep(delay)

    def type_text(self, text: str, delay_ms: int = 10) -> None:
        self.require_window()
        self.event("type", text=text)
        run(
            "xdotool",
            "type",
            "--window",
            self.window,
            "--delay",
            str(delay_ms),
            "--",
            text,
        )
        time.sleep(0.06)

    def click(self, x: int, y: int, button: int = 1, delay: float = 0.08) -> None:
        self.require_window()
        self.event("click", x=x, y=y, button=button)
        run(
            "xdotool",
            "mousemove",
            "--window",
            self.window,
            str(x),
            str(y),
            "click",
            str(button),
        )
        time.sleep(delay)

    def move(self, x: int, y: int, delay: float = 0.08) -> None:
        self.require_window()
        self.event("move", x=x, y=y)
        run("xdotool", "mousemove", "--window", self.window, str(x), str(y))
        time.sleep(delay)

    def move_relative(self, dx: int, dy: int = 0, steps: int = 6, delay: float = 0.06) -> None:
        """Move the mouse *by* an offset, the way a real mouse reports motion.

        A field drag pins the pointer and warps it back after every move, so what
        it consumes is relative motion. Absolute `mousemove` fights that: the
        pointer is put back on its anchor and the next absolute move re-applies
        the whole offset from it.
        """
        self.require_window()
        self.event("move_relative", dx=dx, dy=dy, steps=steps)
        for _ in range(steps):
            run(
                "xdotool",
                "mousemove_relative",
                "--sync",
                "--",
                str(round(dx / steps)),
                str(round(dy / steps)),
            )
            time.sleep(delay)

    def wheel(self, x: int, y: int, clicks: int = 1, up: bool = True, delay: float = 0.25) -> None:
        """Scroll the wheel over a point. Over the map this zooms the camera,
        which is the only way to get close enough to *see* what a scenario placed
        -- the default camera is so far out that a feature is a few pixels.
        """
        self.require_window()
        self.event("wheel", x=x, y=y, clicks=clicks, up=up)
        button = "4" if up else "5"
        run("xdotool", "mousemove", "--window", self.window, str(x), str(y))
        for _ in range(clicks):
            run("xdotool", "click", "--window", self.window, button)
            time.sleep(0.05)
        time.sleep(delay)

    def wheel_root(self, x: int, y: int, clicks: int = 1, up: bool = True, delay: float = 0.25) -> None:
        """Scroll the wheel with the real pointer, so a held modifier applies.

        `xdotool click --window` synthesises the event with the modifier state
        cleared -- the engine then reports shift as up -- so a Shift+wheel chord
        has to go through the root window, as `key` does for the same reason.
        """
        self.event("wheel_root", x=x, y=y, clicks=clicks, up=up)
        button = "4" if up else "5"
        run("xdotool", "mousemove", str(x), str(y))
        for _ in range(clicks):
            run("xdotool", "click", button)
            time.sleep(0.05)
        time.sleep(delay)

    def click_root(self, x: int, y: int, button: int = 1, delay: float = 0.08) -> None:
        self.event("click_root", x=x, y=y, button=button)
        run("xdotool", "mousemove", str(x), str(y), "click", str(button))
        time.sleep(delay)

    def drag_root(
        self,
        x1: int,
        y1: int,
        x2: int,
        y2: int,
        button: int = 1,
        steps: int = 12,
        step_delay: float = 0.03,
    ) -> None:
        # Root-coordinate drag for modal dialogs, stepped like drag().
        self.event("drag_root", x1=x1, y1=y1, x2=x2, y2=y2, button=button, steps=steps)
        run("xdotool", "mousemove", str(x1), str(y1))
        run("xdotool", "mousedown", str(button))
        time.sleep(step_delay)
        for i in range(1, steps + 1):
            xi = round(x1 + (x2 - x1) * i / steps)
            yi = round(y1 + (y2 - y1) * i / steps)
            run("xdotool", "mousemove", str(xi), str(yi))
            time.sleep(step_delay)
        run("xdotool", "mouseup", str(button))
        time.sleep(0.12)

    def press(self, x: int, y: int, button: int = 1, delay: float = 0.15) -> None:
        """Hold the button down. Pair with `move` + `release` when the scenario
        has to capture something that only exists *during* the drag, like the
        selection rectangle."""
        self.require_window()
        self.event("press", x=x, y=y, button=button)
        run("xdotool", "mousemove", "--window", self.window, str(x), str(y))
        run("xdotool", "mousedown", str(button))
        time.sleep(delay)

    def release(self, x: int, y: int, button: int = 1, delay: float = 0.3) -> None:
        self.require_window()
        self.event("release", x=x, y=y, button=button)
        run("xdotool", "mousemove", "--window", self.window, str(x), str(y))
        run("xdotool", "mouseup", str(button))
        time.sleep(delay)

    def drag(
        self,
        x1: int,
        y1: int,
        x2: int,
        y2: int,
        button: int = 1,
        steps: int = 12,
        step_delay: float = 0.03,
    ) -> None:
        # Move in increments rather than one jump: widgets that track drags
        # per mouse-move (or per frame) never see an instantaneous warp, so a
        # single-step drag reads as a plain click.
        self.require_window()
        self.event("drag", x1=x1, y1=y1, x2=x2, y2=y2, button=button, steps=steps)
        run("xdotool", "mousemove", "--window", self.window, str(x1), str(y1))
        run("xdotool", "mousedown", str(button))
        time.sleep(step_delay)
        for i in range(1, steps + 1):
            xi = round(x1 + (x2 - x1) * i / steps)
            yi = round(y1 + (y2 - y1) * i / steps)
            run("xdotool", "mousemove", "--window", self.window, str(xi), str(yi))
            time.sleep(step_delay)
        run("xdotool", "mouseup", str(button))
        time.sleep(0.12)

    def screenshot(self, name: str) -> Path:
        self.require_window()
        stem = f"{len(self.screenshots):02d}-{name}"
        raw_path = self.screenshot_dir / f"{stem}.xwd"
        png_path = self.screenshot_dir / f"{stem}.png"
        start = time.monotonic()
        run("xwd", "-silent", "-id", self.window, "-out", str(raw_path))
        if self.capture == "png":
            self.convert_screenshot(raw_path, png_path)
        elapsed_ms = int((time.monotonic() - start) * 1000)
        shot = Screenshot(
            name=name,
            raw_path=raw_path,
            png_path=png_path,
            crop=self.case.crop,
        )
        self.screenshots.append(shot)
        if self.review_images and self.capture == "raw":
            self.queue_conversion(shot)
        self.event(
            "screenshot",
            name=name,
            raw_path=str(raw_path),
            path=str(png_path),
            elapsed_ms=elapsed_ms,
            capture=self.capture,
        )
        return png_path

    def count_color(
        self,
        shot: Path,
        region: tuple[int, int, int, int],
        color: str = "#00FF00",
        fuzz: str = "12%",
    ) -> int:
        """Pixels of one colour inside an `(x, y, w, h)` box.

        For overlays the editor draws in a flat colour -- the selection box is
        pure green -- this is worth far more than comparing frames: the map sways
        in the wind and the panel animates, so "how many pixels changed" is mostly
        noise, while "is the green box there" is exact.
        """
        by_png = {captured.png_path: captured.raw_path for captured in self.screenshots}
        try:
            raw = by_png[shot]
        except KeyError as exc:
            raise AssertionError(f"unknown screenshot {exc.args[0]}") from exc

        x, y, width, height = region
        result = subprocess.run(
            [
                "convert", str(raw),
                "-crop", f"{width}x{height}+{x}+{y}", "+repage",
                "-fuzz", fuzz,
                "-fill", "black", "+opaque", color,
                "-fill", "white", "-opaque", color,
                "-format", "%[fx:int(mean*w*h)]", "info:",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(f"ImageMagick failed: {result.stderr.strip()}")
        count = int(result.stdout.strip())
        self.event("count_color", shot=shot.name, color=color, count=count)
        return count

    def assert_region_pixels(
        self,
        before: Path,
        after: Path,
        region: tuple[int, int, int, int],
        *,
        min_changed: int = 0,
        max_changed: int | None = None,
    ) -> int:
        """`assert_screenshot_pixels`, restricted to one `(x, y, w, h)` box.

        Whole-frame comparisons are close to useless in this UI: the dev console
        prints a line or two every second and the definition thumbnails spin, so
        any two frames differ by thousands of pixels no matter what is being
        tested. Compare the patch of screen the assertion is actually about.
        """
        x, y, width, height = region
        # The raw captures, as `assert_screenshot_pixels` does: in `raw` mode the
        # PNGs are not written until the run ends.
        by_png = {shot.png_path: shot.raw_path for shot in self.screenshots}
        crops = []
        for shot in (before, after):
            try:
                raw = by_png[shot]
            except KeyError as exc:
                raise AssertionError(f"unknown screenshot {exc.args[0]}") from exc
            cropped = raw.with_name(f"{raw.stem}-crop.png")
            run(
                "convert",
                str(raw),
                "-crop",
                f"{width}x{height}+{x}+{y}",
                "+repage",
                str(cropped),
            )
            crops.append(cropped)
        return self._compare(crops[0], crops[1], min_changed, max_changed)

    def assert_screenshot_pixels(
        self,
        before: Path,
        after: Path,
        *,
        min_changed: int = 0,
        max_changed: int | None = None,
    ) -> int:
        """Assert an exact changed-pixel range between two captured frames.

        Compare the immediate XWD captures so this works with both deferred
        `raw` conversion and immediate `png` capture modes.
        """
        by_png = {shot.png_path: shot.raw_path for shot in self.screenshots}
        try:
            before_raw = by_png[before]
            after_raw = by_png[after]
        except KeyError as exc:
            raise AssertionError(f"unknown screenshot {exc.args[0]}") from exc
        return self._compare(before_raw, after_raw, min_changed, max_changed)

    def _compare(
        self,
        before: Path,
        after: Path,
        min_changed: int,
        max_changed: int | None,
    ) -> int:
        result = subprocess.run(
            ["compare", "-metric", "AE", str(before), str(after), "null:"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode not in (0, 1):
            raise AssertionError(f"ImageMagick compare failed: {result.stderr.strip()}")
        try:
            changed = int(float(result.stderr.strip()))
        except ValueError as exc:
            raise AssertionError(f"invalid compare metric: {result.stderr!r}") from exc

        if changed < min_changed or (max_changed is not None and changed > max_changed):
            expected = f">= {min_changed}"
            if max_changed is not None:
                expected += f" and <= {max_changed}"
            raise AssertionError(
                f"expected changed pixels {expected}, got {changed}: "
                f"{before.name} -> {after.name}"
            )
        self.event(
            "assert_pixels",
            before=before.name,
            after=after.name,
            changed=changed,
            min=min_changed,
            max=max_changed,
        )
        return changed

    # ── Golden images ──────────────────────────────────────────────

    def park_cursor(self) -> None:
        """Move the cursor somewhere harmless before a capture: the engine draws
        it, so wherever it rests becomes part of the image."""
        assert self.window is not None
        width, height = window_geometry(self.window)
        run("xdotool", "mousemove", "--window", self.window, str(width // 2), str(height - 4))
        time.sleep(0.25)

    def golden(self, name: str, crop: str | None = _CASE_CROP) -> None:
        """Capture, then compare pixel-exactly against the checked-in golden.

        `crop` defaults to the case's crop; pass it explicitly for a shot whose
        subject sits outside that region (a modal beside the panel, say).
        """
        self.park_cursor()
        stem = f"{len(self.screenshots):02d}-{name}"
        raw_path = self.screenshot_dir / f"{stem}.xwd"
        png_path = self.screenshot_dir / f"{stem}.png"
        run("xwd", "-silent", "-id", self.window, "-out", str(raw_path))
        if crop is _CASE_CROP:
            crop = self.case.crop
        shot = Screenshot(name=name, raw_path=raw_path, png_path=png_path, crop=crop)
        convert_screenshot_file(shot)
        self.screenshots.append(shot)
        raw_path.unlink(missing_ok=True)

        status = compare_golden(
            self.case.name, name, png_path, update=self.update_golden
        )
        self.golden_results.append((name, status))
        self.event("golden", name=name, status=status, path=str(png_path))

    # ── Command-log assertions ─────────────────────────────────────

    def commands(self) -> list[dict]:
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
        entries = []
        for line in path.read_text().splitlines():
            _stamp, _, payload = line.partition(" ")
            if not payload:
                continue
            entry = json.loads(payload)
            entries.append(entry)
            data = entry.get("data", {})
            if data.get("className") == "CompoundCommand":
                for inner in data.get("commands", []):
                    entries.append({**entry, "data": inner})
        return entries

    def assert_command(self, class_name: str, **expected: object) -> dict:
        """Assert exactly one committed command of `class_name` carrying every
        key in `expected` was sent, and that those values match.

        A value may be a callable predicate, for things like a colour that is
        "red enough" rather than an exact float. Matching on the keys as well as
        the class lets one editor emit several commands of the same class.

        Previews (`__preview`) are excluded: they apply to the engine but never
        reach the undo history, and a drag emits a stream of them. Use
        `assert_previews` for those.
        """
        committed = [
            entry["data"]
            for entry in self.commands()
            if not entry.get("data", {}).get("__preview")
        ]
        matches = [
            data
            for data in committed
            if data.get("className") == class_name
            and all(key in command_fields(data) for key in expected)
        ] or [
            data
            for data in committed
            if data.get("className") == class_name and not expected
        ]
        if len(matches) != 1:
            sent = [
                (e["data"].get("className"), sorted(command_fields(e["data"])))
                for e in self.commands()
            ]
            raise AssertionError(
                f"expected exactly one {class_name} with keys {sorted(expected)}, "
                f"got {len(matches)}. Sent: {sent}"
            )
        data = matches[0]
        opts = command_fields(data)
        for key, want in expected.items():
            got = opts.get(key)
            ok = want(got) if callable(want) else got == want
            if not ok:
                raise AssertionError(f"{class_name}.{key}: expected {want!r}, got {got!r}")
        self.event("assert_command", className=class_name, keys=sorted(expected))
        return data

    def assert_no_command_after(self, marker: dict, class_name: str, **expected: object) -> None:
        """Assert nothing more of this kind was sent after `marker`.

        For proving something *stopped*: a drag that was released must not keep
        emitting as the mouse moves on.
        """
        seen_marker = False
        for entry in self.commands():
            data = entry.get("data", {})
            if data is marker or data.get("__cmd_id") == marker.get("__cmd_id"):
                seen_marker = True
                continue
            if not seen_marker or data.get("className") != class_name:
                continue
            fields = command_fields(data)
            if all(fields.get(key) == want for key, want in expected.items() if not callable(want)):
                raise AssertionError(
                    f"{class_name} was still being sent after the drag ended: {fields}"
                )

    def assert_command_count(self, class_name: str, count: int) -> None:
        """Assert exactly `count` committed commands of this class were sent.

        For things whose whole point is *how many*: placing with an amount of 5
        must emit five adds, not one.
        """
        sent = [
            entry["data"]
            for entry in self.commands()
            if entry.get("data", {}).get("className") == class_name
            and not entry.get("data", {}).get("__preview")
        ]
        if len(sent) != count:
            raise AssertionError(
                f"expected {count} committed {class_name}, got {len(sent)}"
            )
        self.event("assert_command_count", className=class_name, count=count)

    def assert_any_command(self, class_name: str, **expected: object) -> dict:
        """Assert at least one committed command matched `expected`.

        Brush scenarios often exercise several modes of the same command class;
        this keeps the assertion about the specific mode/property rather than
        requiring the scenario to isolate every click in a fresh process.
        """
        for entry in self.commands():
            data = entry.get("data", {})
            if data.get("__preview") or data.get("className") != class_name:
                continue
            opts = command_fields(data)
            if all(key in opts for key in expected) and all(
                want(opts.get(key)) if callable(want) else opts.get(key) == want
                for key, want in expected.items()
            ):
                self.event("assert_any_command", className=class_name, keys=sorted(expected))
                return data
        sent = [
            (e["data"].get("className"), sorted(command_fields(e["data"])))
            for e in self.commands()
            if e.get("data", {}).get("className") == class_name
        ]
        raise AssertionError(
            f"expected at least one {class_name} matching {expected}, got {sent}"
        )

    def assert_previews(self, class_name: str, **expected: object) -> int:
        """Assert at least one *preview* of `class_name` matched `expected`.

        A live drag emits one per frame, so the count is timing-dependent; that
        any arrived, carrying the right value, is the deterministic part.
        """
        matches = [
            entry["data"]
            for entry in self.commands()
            if entry.get("data", {}).get("__preview")
            and entry["data"].get("className") == class_name
            and all(key in entry["data"].get("opts", {}) for key in expected)
        ]
        good = []
        for data in matches:
            opts = data.get("opts", data)
            if all(
                want(opts.get(key)) if callable(want) else opts.get(key) == want
                for key, want in expected.items()
            ):
                good.append(data)
        if not good:
            raise AssertionError(
                f"expected at least one {class_name} preview matching "
                f"{sorted(expected)}, got {len(matches)} previews of that class"
            )
        self.event("assert_previews", className=class_name, count=len(good))
        return len(good)

    def screenshot_root(self, name: str) -> Path:
        """A full-frame capture, for a subject that sits outside the case's crop
        (a modal beside the panel).

        This captures the *engine window*, not the X root. Modals are RmlUi drawn
        inside that window, so there is nothing on the root to see -- and grabbing
        the whole desktop wrote ~29MB per shot through a separate, flakier path
        that intermittently failed mid-run (`xwd -root` returning 1). Capturing by
        window id is the same call every other screenshot already makes.
        """
        self.require_window()
        stem = f"{len(self.screenshots):02d}-{name}"
        raw_path = self.screenshot_dir / f"{stem}.xwd"
        png_path = self.screenshot_dir / f"{stem}.png"
        start = time.monotonic()
        run("xwd", "-silent", "-id", self.window, "-out", str(raw_path))
        if self.capture == "png":
            self.convert_screenshot(raw_path, png_path)
        elapsed_ms = int((time.monotonic() - start) * 1000)
        shot = Screenshot(
            name=name,
            raw_path=raw_path,
            png_path=png_path,
            crop=None,
        )
        self.screenshots.append(shot)
        if self.review_images and self.capture == "raw":
            self.queue_conversion(shot)
        self.event(
            "screenshot_root",
            name=name,
            raw_path=str(raw_path),
            path=str(png_path),
            elapsed_ms=elapsed_ms,
            capture=self.capture,
        )
        return png_path

    def queue_conversion(self, shot: Screenshot) -> None:
        if self.image_pool is None:
            return
        self.image_futures.append(self.image_pool.submit(convert_screenshot_file, shot))

    def finish_conversions(self) -> None:
        for future in concurrent.futures.as_completed(self.image_futures):
            shot, elapsed_ms = future.result()
            self.event(
                "screenshot_convert",
                name=shot.name,
                raw_path=str(shot.raw_path),
                path=str(shot.png_path),
                elapsed_ms=elapsed_ms,
                async_workers=self.image_workers,
            )
        self.image_futures.clear()
        if self.image_pool is not None:
            self.image_pool.shutdown(wait=True)
            self.image_pool = None
        if self.capture != "png":
            for shot in self.screenshots:
                if not shot.png_path.is_file():
                    self.convert_screenshot(shot.raw_path, shot.png_path)
        self.discard_raw_captures()

    def discard_raw_captures(self) -> None:
        # The .xwd captures are uncompressed (14-29MB each) and are only an
        # intermediate for the PNG. Keeping them made artifacts/ grow into the
        # tens of GB. Drop each one once its PNG exists.
        for shot in self.screenshots:
            if shot.png_path.is_file() and shot.raw_path.is_file():
                shot.raw_path.unlink()

    def convert_screenshot(self, raw_path: Path, png_path: Path) -> None:
        convert_screenshot_file(Screenshot("", raw_path, png_path))

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

    def generate_contact_sheet(self) -> None:
        if not self.screenshots or shutil.which("montage") is None:
            return
        path = self.out_dir / "contact-sheet.png"
        cmd = [
            "montage",
            *[str(shot.png_path) for shot in self.screenshots],
            "-thumbnail",
            "480x263",
            "-label",
            "%f",
            "-tile",
            "2x",
            "-geometry",
            "+8+28",
            str(path),
        ]
        result = run(*cmd, check=False)
        if result.returncode == 0:
            self.contact_sheet = path
            self.event("contact_sheet", path=str(path))
        else:
            self.event("contact_sheet_failed", stderr=result.stderr)

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
