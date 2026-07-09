#!/usr/bin/env python3
"""Launch the SBC editor, wait for it to reach in-game, and capture screenshots."""

import os
import re
import subprocess
import sys
import time
from pathlib import Path

# Reuse the project's launch infrastructure
sys.path.insert(0, str(Path(__file__).parent.parent / "smoke"))
from run_sbc import prepare  # noqa: E402

SCREENSHOT_DIR = Path("/tmp/sbc-panel-screenshots")


def find_window():
    """Find the Spring/Recoil editor window."""
    try:
        result = subprocess.run(
            ["xdotool", "search", "--name", "Recoil"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            wid = result.stdout.strip().split("\n")[0]
            return int(wid)
    except Exception:
        pass
    # Try "Spring" as fallback
    try:
        result = subprocess.run(
            ["xdotool", "search", "--name", "Spring"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            wid = result.stdout.strip().split("\n")[0]
            return int(wid)
    except Exception:
        pass
    return None


def screenshot(window_id, name):
    """Capture a screenshot of the window."""
    path = SCREENSHOT_DIR / f"{name}.png"
    subprocess.run(
        ["import", "-window", str(window_id), str(path)],
        check=True, timeout=10
    )
    print(f"  screenshot: {path}")
    return path


def wait_for_window(timeout_s=90):
    """Wait for the editor window to appear."""
    print("Waiting for editor window...", flush=True)
    start = time.monotonic()
    while time.monotonic() - start < timeout_s:
        wid = find_window()
        if wid:
            print(f"  Found window {wid} after {time.monotonic() - start:.0f}s")
            return wid
        time.sleep(2)
    return None


def wait_for_ingame(write_dir, timeout_s=60):
    """Wait for the engine to reach in-game by checking infolog for frame 0."""
    infolog = write_dir / "infolog.txt"
    print("Waiting for in-game state...", flush=True)
    start = time.monotonic()
    while time.monotonic() - start < timeout_s:
        if infolog.is_file():
            try:
                text = infolog.read_text(errors="replace")
                if "game_setup" in text.lower() or "GameID" in text or "Sim/frame" in text:
                    print(f"  In-game after {time.monotonic() - start:.0f}s")
                    return True
            except Exception:
                pass
        time.sleep(2)
    print("  WARNING: did not detect in-game state, capturing anyway")
    return False


def main():
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)

    # Launch the editor
    write_dir, env, cmd = prepare(prefix="sbc-panel-test-")
    print(f"Write dir: {write_dir}")
    print(f"Launching: {' '.join(cmd[:4])} ...")

    proc = subprocess.Popen(cmd, env=env)

    try:
        wid = wait_for_window(timeout_s=90)
        if not wid:
            print("ERROR: No editor window found")
            proc.terminate()
            return 1

        # Give it a few more seconds to finish loading
        time.sleep(5)
        wait_for_ingame(write_dir, timeout_s=30)

        # Give it a few more seconds for UI to settle
        time.sleep(5)

        # Capture: initial state (should show the Rust panel on the left)
        print("Capturing screenshots...")
        screenshot(wid, "01-initial")

        # Focus the window and capture again
        subprocess.run(["xdotool", "windowactivate", str(wid)], timeout=5)
        subprocess.run(["xdotool", "windowfocus", str(wid)], timeout=5)
        time.sleep(1)
        screenshot(wid, "02-focused")

        # Check infolog for any panel-related errors
        infolog = write_dir / "infolog.txt"
        if infolog.is_file():
            log = infolog.read_text(errors="replace")
            for line in log.splitlines():
                if "panel" in line.lower() or "native env panel" in line.lower():
                    print(f"  INFOLOG: {line.strip()}")

        print("\nDone. Screenshots saved to", SCREENSHOT_DIR)
        print("Editor still running. Press Ctrl+C to kill it.")

        # Keep running until killed
        proc.wait()

    except KeyboardInterrupt:
        print("\nInterrupted, killing editor...")
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()

    return 0


if __name__ == "__main__":
    sys.exit(main())
