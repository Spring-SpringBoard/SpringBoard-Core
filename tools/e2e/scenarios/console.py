"""The chonsole and the developer console."""

from __future__ import annotations

from typing import TYPE_CHECKING

from scenarios.geometry import EDITOR_BUTTON_Y, window_size
from scenarios.objects import _arm_tree, _open
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
    """Lua/Rust editing parity: opening, completions, word editing, and /help."""
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
    # Run native Chonsole with the Rust UI too: it prevents the legacy Lua
    # cursor tooltip from affecting interaction assertions.
    "chonsole-native-smoke": {"chonsole": "rust", "ui": "rust"},
}

NATIVE_RELOAD_CASE = {
    "e2e-reloadnativemodules-rust": {"chonsole": "rust", "ui": "rust"},
}


@scenario(target="e2e-reloadnativemodules", cases=NATIVE_RELOAD_CASE)
def reload_native_modules(run_state: E2ERun) -> None:
    """Native reload preserves input and can re-adopt pre-reload engine features.

    The engine feature survives while Rust's in-memory model is recreated. The
    replacement module must therefore accept Chonsole input and select/edit the
    original feature instead of treating it as unknown scenery.
    """
    run_state.focus()
    left = _open(run_state, 110)                      # Features
    _arm_tree(run_state, left)
    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    run_state.wheel(spot_x, spot_y, clicks=8, up=True)
    run_state.click(spot_x, spot_y, delay=0.8)        # place before reload
    run_state.key("Escape", delay=0.2)                # leave placement mode

    run_state.key("Return", delay=0.18)
    run_state.type_text("/reloadnativemodules")
    # Reload is deliberately deferred by the engine until all event callbacks
    # have returned. The delay covers that next update; assert_running catches
    # ASAN aborts from unloading a module on its own Chonsole callback stack.
    run_state.key("Return", delay=0.7)
    run_state.assert_running()
    run_state.key("Return", delay=0.18)
    run_state.type_text("/h")
    run_state.assert_running()
    run_state.key("Escape", delay=0.2)

    # The feature was created by the module instance we just unloaded. Clicking
    # it forces the replacement instance to recreate its springID -> modelID
    # mapping; Properties then proves the selection is a live editable object.
    run_state.click(spot_x, spot_y, delay=0.4)
    run_state.click(left + 197, EDITOR_BUTTON_Y, delay=0.5)  # Properties
    run_state.click(left + 58, 241, delay=0.2)               # Pos X
    run_state.key("ctrl+a", delay=0.1)
    run_state.type_text("1800")
    run_state.key("Return", delay=0.5)
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=lambda v: isinstance(v, dict) and abs(v.get("x", 0) - 1800) < 1.0,
    )


@scenario(target="chonsole-native-input", cases=NATIVE_CHONSOLE_CASE)
def chonsole_native_input(run_state: E2ERun) -> None:
    """Native input editing: Ctrl+word navigation, selection replacement, and Ctrl+A."""
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


@scenario(target="chonsole-native-suggestions", cases=NATIVE_CHONSOLE_CASE)
def chonsole_native_suggestions(run_state: E2ERun) -> None:
    """Native suggestions keep their list while Tab-cycling, hovering, and clicking.

    Tab must reach Chonsole before RmlUi can move focus to the editor's search
    field or toolbar. Repeated presses select successive matches from the
    original query, rather than completing the first match and losing the list.
    """
    run_state.focus()
    _open(run_state, 110)                            # Features, with search input
    run_state.key("Escape")
    run_state.key("Return", delay=0.18)
    run_state.type_text("/h")
    matches = run_state.screenshot("matches")
    width, height = window_size(run_state)
    suggestion_box = (
        int(width * 0.26),
        int(height * 0.245),
        int(width * 0.41),
        int(height * 0.4),
    )

    run_state.key("Tab")
    first = run_state.screenshot("first-selected")
    run_state.assert_region_pixels(matches, first, suggestion_box, min_changed=100)

    run_state.key("Tab")
    second = run_state.screenshot("second-selected")
    run_state.assert_region_pixels(first, second, suggestion_box, min_changed=100)

    row_x = int(width * 0.26) + 40
    third_row_y = int(height * 0.245) + 38 + 4 + 12 + 2 * 27
    run_state.move(row_x, third_row_y, delay=0.25)
    hovered = run_state.screenshot("third-row-hovered")
    run_state.assert_region_pixels(second, hovered, suggestion_box, min_changed=100)

    run_state.click(row_x, third_row_y)
    clicked = run_state.screenshot("third-row-clicked")
    run_state.assert_region_pixels(hovered, clicked, suggestion_box, min_changed=100)

    # `/set` exposes the engine configuration catalogue, which is long enough
    # to exercise a real scrollbar in the deterministic test map.
    # Escape clears Chonsole's input; reopening avoids relying on selection
    # ownership just after the click assertion above.
    run_state.key("Escape")
    run_state.key("Return", delay=0.18)
    run_state.type_text("/set ")
    run_state.move(row_x, int(height * 0.245) + 18)
    unhovered = run_state.screenshot("scroll-start")
    scrollbar_x = int(width * (0.26 + 0.41)) - 5
    scrollbar_y = int(height * 0.245) + 38 + 80
    run_state.move(scrollbar_x, scrollbar_y)
    scrollbar_hovered = run_state.screenshot("scrollbar-hovered")
    scrollbar = (scrollbar_x - 6, int(height * 0.245) + 38, 12, 380)
    run_state.assert_region_pixels(unhovered, scrollbar_hovered, scrollbar, min_changed=40)
    # Hover must colour the scrollbar without changing the suggestions' layout.
    suggestion_content = (*suggestion_box[:2], suggestion_box[2] - 24, suggestion_box[3])
    suggestion_rows = (
        suggestion_content[0],
        suggestion_content[1] + 38,
        suggestion_content[2],
        suggestion_content[3] - 38,
    )
    # Captures include the engine cursor; its edge can spill a few pixels into
    # the first row, but a layout reflow would alter thousands of text pixels.
    run_state.assert_region_pixels(unhovered, scrollbar_hovered, suggestion_rows, max_changed=50)

    # Leaving and re-entering the list must not reset either wheel or thumb
    # scrolling. This used to happen because hover rebuilt the suggestion DOM.
    run_state.move(row_x, third_row_y, delay=0.25)
    scroll_start = run_state.screenshot("wheel-scroll-start")
    run_state.wheel(row_x, third_row_y, clicks=6, up=False)
    scroll_down = run_state.screenshot("wheel-scroll-down")
    run_state.assert_region_pixels(scroll_start, scroll_down, suggestion_box, min_changed=100)
    run_state.move(int(width * 0.70), third_row_y)
    run_state.move(row_x, third_row_y)
    scroll_reentered = run_state.screenshot("wheel-scroll-reentered")
    run_state.assert_region_pixels(scroll_down, scroll_reentered, suggestion_box, max_changed=0)

    # Restart at the top, drag the thumb, then prove that re-entering still
    # leaves the dragged position alone.
    run_state.key("Escape")
    run_state.key("Return", delay=0.18)
    run_state.type_text("/set ")
    drag_start = run_state.screenshot("drag-scroll-start")
    # The track begins at `scrollbar_x`; its thumb is inset by the track's
    # margin, so drag its centre rather than the track beside it.
    thumb_x = scrollbar_x + 7
    run_state.drag(thumb_x, int(height * 0.245) + 38 + 12, thumb_x,
                   int(height * 0.245) + 38 + 300)
    drag_down = run_state.screenshot("drag-scroll-down")
    run_state.assert_region_pixels(drag_start, drag_down, suggestion_box, min_changed=100)
    run_state.move(int(width * 0.70), third_row_y)
    run_state.move(scrollbar_x, scrollbar_y)
    drag_reentered = run_state.screenshot("drag-scroll-reentered")
    run_state.assert_region_pixels(drag_down, drag_reentered, suggestion_content, max_changed=0)


@scenario(target="chonsole-native-commands", cases=NATIVE_CHONSOLE_CASE)
def chonsole_native_commands(run_state: E2ERun) -> None:
    """Native command completion: engine commands, texture preview, and game-rule values."""
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
    """Lua developer consoles: line selection, Ctrl+C/Ctrl+A ownership, and F8 hiding."""
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
    empty log is the deterministic state. The toolbar, F8 visibility, and the
    scen_edit status/command strip below it are what these goldens pin down.
    """
    run_state.focus()
    width, height = window_size(run_state)
    # The console is 300dp tall and floats 92dp off the bottom; its toolbar row
    # centres 108px above the window's bottom edge.
    toolbar_y = height - 108

    run_state.key("F8", delay=0.6)                     # the harness starts it hidden
    run_state.click(30, toolbar_y, delay=0.5)          # Clear
    run_state.golden("console-cleared")

    # The status strip is not part of the console, but it is positioned directly
    # below it. Its undo/redo/clear controls must enter the same native command
    # path as their editor hotkeys, even when history is empty.
    # RmlUi applies the 34dp icon width to the button's content box; 5dp padding
    # and 1dp borders make its actual hit target 46dp, followed by a 10dp gap.
    # Derive the centres from that real geometry at every E2E resolution.
    status_toolbar_left = round((width - 500) * 0.55) + 10
    status_button_x = [status_toolbar_left + 23 + 56 * index for index in range(3)]
    run_state.click(status_button_x[0], height - 40, delay=0.4)
    run_state.assert_any_command("UndoCommand")
    run_state.click(status_button_x[1], height - 40, delay=0.4)
    run_state.assert_any_command("RedoCommand")
    run_state.click(status_button_x[2], height - 40, delay=0.4)
    run_state.assert_any_command("ClearUndoRedoCommand")
    run_state.golden("status-bar")

    run_state.click(300, toolbar_y, delay=0.5)         # Problems
    run_state.golden("console-problems-on")

    run_state.click(300, toolbar_y, delay=0.5)         # Problems (off again)
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
