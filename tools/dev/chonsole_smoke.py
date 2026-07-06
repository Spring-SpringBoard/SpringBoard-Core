#!/usr/bin/env python3
"""Drive the native chonsole in a live Recoil/Spring window.

This is intentionally small and boring: it finds the current editor window,
normalizes modifier state, sends deterministic key sequences, and captures
screenshots so native chonsole UI/input changes can be checked without typing
by hand.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from pathlib import Path


WINDOW_RE = "Recoil 2026.06.06-111-g0bcccec"
OUT_DIR = Path("/tmp")
MODIFIERS = ("Control_L", "Control_R", "Shift_L", "Shift_R", "Alt_L", "Alt_R", "Super_L", "Super_R")
MODIFIER_NAMES = {
    "ctrl": "Control_L",
    "control": "Control_L",
    "shift": "Shift_L",
    "alt": "Alt_L",
}


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(args),
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def find_window() -> str:
    result = run("xdotool", "search", "--name", WINDOW_RE, check=False)
    ids = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not ids:
        raise RuntimeError(f"no Recoil window found matching {WINDOW_RE!r}")
    active = spring_processes()
    if active:
        for window_id in reversed(ids):
            pid = window_pid(window_id)
            line = active.get(pid) if pid is not None else None
            if line is not None and "/tmp/sbc-manual-" in line:
                return window_id
        for window_id in reversed(ids):
            pid = window_pid(window_id)
            if pid in active:
                return window_id
    return ids[-1]


def spring_processes() -> dict[int, str]:
    result = run("ps", "-ef", check=False)
    processes = {}
    for line in result.stdout.splitlines():
        if "spring --isolation" not in line or "rg " in line:
            continue
        parts = line.split()
        if len(parts) > 1 and parts[1].isdigit():
            processes[int(parts[1])] = line
    return processes


def window_pid(window_id: str) -> int | None:
    result = run("xprop", "-id", window_id, "_NET_WM_PID", check=False)
    match = re.search(r"=\s*(\d+)", result.stdout)
    return int(match.group(1)) if match else None


def active_write_dir(window: str) -> Path | None:
    pid = window_pid(window)
    if pid is None:
        return None
    line = spring_processes().get(pid)
    if line is None:
        return None
    match = re.search(r"--write-dir\s+(\S+)", line)
    return Path(match.group(1)) if match else None


def focus(window: str) -> None:
    run("xdotool", "windowactivate", window, "windowfocus", window)
    time.sleep(0.15)


def release_modifiers(window: str | None = None) -> None:
    args = ["xdotool"]
    for modifier in MODIFIERS:
        args += ["keyup"]
        if window is not None:
            args += ["--window", window]
        args += [modifier]
    run(*args, check=False)
    time.sleep(0.05)


def key(window: str, name: str, delay: float = 0.08) -> None:
    run("xdotool", "key", "--window", window, name)
    time.sleep(delay)


def key_chord(window: str, modifiers: tuple[str, ...], name: str, delay: float = 0.12) -> None:
    normalized = tuple(MODIFIER_NAMES.get(modifier, modifier) for modifier in modifiers)
    run("xdotool", "key", "--window", window, "+".join((*normalized, name)))
    time.sleep(delay)


def type_text(window: str, text: str, delay_ms: int = 20) -> None:
    run("xdotool", "type", "--window", window, "--delay", str(delay_ms), text)
    time.sleep(0.08)


def screenshot(window: str, name: str) -> Path:
    path = OUT_DIR / f"sbc-chonsole-{name}.png"
    run("import", "-window", window, str(path))
    print(path)
    return path


def open_empty(window: str) -> None:
    focus(window)
    release_modifiers(window)
    key(window, "Escape", delay=0.12)
    key(window, "Return", delay=0.16)


def scenario_enter(window: str) -> None:
    focus(window)
    release_modifiers(window)
    key(window, "Return")
    screenshot(window, "enter")


def scenario_suggestions(window: str) -> None:
    open_empty(window)
    type_text(window, "he")
    screenshot(window, "suggestions")


def scenario_selection(window: str) -> None:
    open_empty(window)
    type_text(window, "hello brave world")
    key_chord(window, ("ctrl", "shift"), "Left")
    screenshot(window, "select-word")
    type_text(window, "friend")
    screenshot(window, "replace-selection")
    key_chord(window, ("ctrl",), "a")
    screenshot(window, "select-all")


def scenario_navigation(window: str) -> None:
    open_empty(window)
    type_text(window, "alpha beta gamma")
    key_chord(window, ("ctrl",), "Left")
    key_chord(window, ("ctrl",), "Left")
    type_text(window, "_")
    key(window, "End")
    type_text(window, "!")
    screenshot(window, "navigation")


def scenario_editing(window: str) -> None:
    open_empty(window)
    type_text(window, "alpha beta gamma")
    key_chord(window, ("ctrl",), "Left")
    key_chord(window, ("ctrl",), "Delete")
    screenshot(window, "ctrl-delete")
    key_chord(window, ("ctrl",), "u")
    type_text(window, "delta epsilon")
    key(window, "Home")
    key_chord(window, ("shift",), "End")
    screenshot(window, "shift-home-end")
    type_text(window, "replacement")
    screenshot(window, "replace-line-selection")


def scenario_suggestion_keys(window: str) -> None:
    open_empty(window)
    key(window, "Down")
    key(window, "Down")
    screenshot(window, "suggestion-down")
    key(window, "Page_Down")
    screenshot(window, "suggestion-page-down")


def scenario_execute(window: str) -> None:
    open_empty(window)
    type_text(window, "persisted smoke")
    key(window, "Return", delay=0.2)
    screenshot(window, "execute")


SCENARIOS = {
    "enter": scenario_enter,
    "suggestions": scenario_suggestions,
    "selection": scenario_selection,
    "navigation": scenario_navigation,
    "editing": scenario_editing,
    "suggestion-keys": scenario_suggestion_keys,
    "execute": scenario_execute,
}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "scenario",
        nargs="?",
        default="enter",
        choices=("all", *SCENARIOS.keys()),
        help="chonsole smoke scenario to run; default is enter-only",
    )
    args = parser.parse_args(argv)

    window = find_window()
    write_dir = active_write_dir(window)
    print(f"window: {window}")
    if write_dir is not None:
        print(f"write_dir: {write_dir}")
        print(f"infolog: {write_dir / 'infolog.txt'}")

    names = SCENARIOS.keys() if args.scenario == "all" else (args.scenario,)
    try:
        for name in names:
            SCENARIOS[name](window)
    finally:
        release_modifiers(window)
    return 0


if __name__ == "__main__":
    sys.exit(main())
