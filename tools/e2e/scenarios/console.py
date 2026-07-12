"""The chonsole and the developer console."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import window_size
from scenarios.registry import scenario

if TYPE_CHECKING:
    from runner import E2ERun


# The one scenario whose cases vary the *chonsole* rather than the UI, so it
# names them itself.
@scenario(
    target="chonsole",
    cases={
        "chonsole-lua-baseline": {"chonsole": "lua", "ui": "chili"},
        "chonsole-rust-port": {"chonsole": "rust", "ui": "chili"},
    },
)
def chonsole_editing(run_state: E2ERun) -> None:
    run_state.focus()
    run_state.key("Escape", delay=0.08)
    run_state.key("Return", delay=0.18)
    run_state.screenshot("chonsole-open")
    run_state.type_text("/he")
    run_state.screenshot("suggestions")
    run_state.key_chord(("ctrl",), "a")
    run_state.type_text("alpha beta gamma")
    run_state.key_chord(("ctrl",), "Left")
    run_state.key_chord(("ctrl",), "Left")
    run_state.type_text("_")
    run_state.key("End")
    run_state.type_text("!")
    run_state.screenshot("navigation")
    run_state.key_chord(("ctrl", "shift"), "Left")
    run_state.screenshot("select-word")
    run_state.type_text("WORLD")
    run_state.screenshot("replace-selection")
    run_state.key_chord(("ctrl",), "a")
    run_state.screenshot("select-all")
    run_state.type_text("/help")
    run_state.key("Return", delay=0.25)
    run_state.screenshot("execute-help")


NATIVE_CHONSOLE_CASE = {
    "chonsole-native-smoke": {"chonsole": "rust", "ui": "chili"},
}


@scenario(target="chonsole-native-input", cases=NATIVE_CHONSOLE_CASE)
def chonsole_native_input(run_state: E2ERun) -> None:
    """The deterministic keyboard cases formerly in tools/dev/chonsole_smoke.py."""
    run_state.focus()
    run_state.key("Escape")
    run_state.key("Return", delay=0.18)
    run_state.screenshot("open")
    run_state.type_text("alpha beta gamma")
    run_state.key_chord(("ctrl",), "Left")
    run_state.key_chord(("ctrl",), "Left")
    run_state.type_text("_")
    run_state.key("End")
    run_state.type_text("!")
    run_state.screenshot("navigation")
    run_state.key_chord(("ctrl", "shift"), "Left")
    run_state.screenshot("select-word")
    run_state.type_text("WORLD")
    run_state.key_chord(("ctrl",), "a")
    run_state.screenshot("select-all")


@scenario(target="chonsole-native-commands", cases=NATIVE_CHONSOLE_CASE)
def chonsole_native_commands(run_state: E2ERun) -> None:
    """Native command discovery, argument completion, texture preview, and rules reads."""
    run_state.focus()
    run_state.key("Escape")
    run_state.key("Return", delay=0.18)
    opened = run_state.screenshot("open")
    run_state.type_text("/")
    commands = run_state.screenshot("all-engine-commands")
    width, height = window_size(run_state)
    run_state.assert_region_pixels(opened, commands, (width // 4, height // 4, width // 2, height // 2), min_changed=100)
    run_state.key_chord(("ctrl",), "a")
    run_state.type_text("/texture ")
    textures = run_state.screenshot("texture-values")
    run_state.assert_region_pixels(commands, textures, (width // 4, height // 4, width // 2, height // 2), min_changed=100)
    run_state.type_text("$ssmf_specular")
    preview = run_state.screenshot("texture-preview")
    run_state.assert_region_pixels(textures, preview, (0, 0, width // 2, height), min_changed=100)
    run_state.key_chord(("ctrl",), "a")
    run_state.type_text("/gamerules ")
    rules = run_state.screenshot("gamerule-values")
    run_state.assert_region_pixels(preview, rules, (width // 4, height // 4, width // 2, height // 2), min_changed=100)


@scenario(uis=("chili", "rmlui"))
def dev_console(run_state: E2ERun) -> None:
    run_state.focus()
    # The console is visible by default; capture it.
    run_state.screenshot("dev-console-open")
    # Drag across several log lines: they must highlight (multi-line selection).
    run_state.drag(100, 965, 600, 1010, steps=10)
    run_state.screenshot("dev-console-selection")
    # Ctrl+C over the console copies the selected lines to the clipboard, and
    # Ctrl+A selects every line first. SpringBoard binds Ctrl+C to Copy, so this
    # also checks it yields to the console.
    run_state.move(300, 985, delay=0.6)
    run_state.key("ctrl+c", delay=0.5)
    run_state.key("ctrl+a", delay=0.4)
    run_state.key("ctrl+c", delay=0.5)
    run_state.screenshot("dev-console-select-all")
    run_state.key("F8", delay=0.6)
    run_state.screenshot("dev-console-hidden")


@scenario(crop="dev-console")
def native_dev_console(run_state: E2ERun) -> None:
    """The native (Rust) developer console.

    Log content varies run to run, so every golden is taken after `Clear`: an
    empty log is the deterministic state. The toolbar and the F8 toggle are
    what these goldens actually pin down.
    """
    run_state.focus()
    _width, height = window_size(run_state)
    # The console is 300dp tall and floats 80dp off the bottom; its toolbar row
    # centres 108px above the window's bottom edge.
    toolbar_y = height - 108

    run_state.key("F8", delay=0.6)                     # the harness starts it hidden
    run_state.click(30, toolbar_y, delay=0.5)          # Clear
    run_state.golden("console-cleared")

    run_state.click(100, toolbar_y, delay=0.5)         # Problems
    run_state.golden("console-problems-on")

    run_state.click(100, toolbar_y, delay=0.5)         # Problems (off again)
    run_state.golden("console-problems-off")

    # F8 hides the console, and brings it back.
    run_state.key("F8", delay=0.6)
    run_state.golden("console-hidden")

    run_state.key("F8", delay=0.6)
    run_state.golden("console-shown")


@scenario()
def native_dev_console_copy(run_state: E2ERun) -> None:
    """Selecting log lines and copying them with Ctrl+C.

    The clipboard is read back: the panel's toolbar binds Ctrl+C to Copy, so this
    is also what proves the console wins the key when it has a selection.
    """
    run_state.focus()
    run_state.key("F8", delay=0.6)                     # the harness starts it hidden
    _width, height = window_size(run_state)
    # The log sits above the toolbar row (108px off the bottom).
    top, bottom = height - 290, height - 140

    # So a stale clipboard from an earlier run cannot pass this.
    run_state.set_clipboard("SENTINEL-NOTHING-WAS-COPIED")

    run_state.drag(60, top, 700, bottom, steps=10)
    run_state.screenshot("lines-selected")

    run_state.key("ctrl+c", delay=0.5)
    copied = run_state.clipboard()
    if not copied.strip() or copied.startswith("SENTINEL"):
        raise AssertionError("Ctrl+C over a console selection copied nothing")

    run_state.key("ctrl+a", delay=0.4)
    run_state.key("ctrl+c", delay=0.5)
    everything = run_state.clipboard()
    if len(everything) <= len(copied):
        raise AssertionError(
            f"Ctrl+A did not widen the selection ({len(everything)} <= {len(copied)} chars)"
        )
