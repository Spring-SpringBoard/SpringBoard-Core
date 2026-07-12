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


