"""The chonsole and the developer console."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.driver.utils.models import object_number_close

if TYPE_CHECKING:
    from e2e.driver.state import RunState

from .helpers.geometry import (
    CHONSOLE,
    DEV_CONSOLE,
    OBJECTS,
    chonsole_header_point,
    chonsole_row_point,
    chonsole_scrollbar_point,
    chonsole_suggestion_box,
    dev_console_toolbar_y,
    editor_point,
    panel_point,
    status_button_point,
    window_size,
)
from .helpers.objects import arm_tree as _arm_tree
from .helpers.objects import open_object_editor as _open
from .helpers.registry import scenario


@scenario(target="e2e-reloadnativemodules")
def reload_native_modules(run_state: "RunState") -> None:
    """Native reload preserves input and can re-adopt pre-reload engine features.

    The engine feature survives while Rust's in-memory model is recreated. The
    replacement module must therefore accept Chonsole input and select/edit the
    original feature instead of treating it as unknown scenery.
    """
    run_state.focus()
    left = _open(run_state, "features")
    _arm_tree(run_state, left)
    width, height = window_size(run_state)
    spot_x, spot_y = width // 3, height // 2
    run_state.wheel(spot_x, spot_y, clicks=8, up=True)
    run_state.click(spot_x, spot_y, delay=Delay.MS_800)  # place before reload
    run_state.key("Escape", delay=Delay.MS_200)  # leave placement mode

    run_state.key("Return", delay=Delay.MS_180)
    run_state.type_text("/reloadnativemodules")
    # Reload is deliberately deferred by the engine until all event callbacks
    # have returned. The delay covers that next update; assert_running catches
    # ASAN aborts from unloading a module on its own Chonsole callback stack.
    run_state.key("Return", delay=Delay.MS_700)
    run_state.assert_running()
    run_state.key("Return", delay=Delay.MS_180)
    run_state.type_text("/h")
    run_state.assert_running()
    run_state.key("Escape", delay=Delay.MS_200)

    # The feature was created by the module instance we just unloaded. Box
    # selection must discover it from the engine, then make it editable through
    # the replacement instance's new springID -> modelID mapping. Direct-click
    # selection alone would not cover this: it has its own lazy adoption path.
    run_state.press(spot_x - 220, 80)
    run_state.move(spot_x + 120, spot_y + 60, delay=Delay.MS_200)
    run_state.release(spot_x + 200, spot_y + 160, delay=Delay.MS_400)
    run_state.click(*editor_point(left, "objects", "properties"), delay=Delay.MS_500)
    run_state.fill_text(
        *panel_point(left, OBJECTS["property_pos_x"]),
        "1800",
        click_delay=Delay.MS_200,
        commit_delay=Delay.MS_500,
    )
    run_state.assert_any_command(
        "SetObjectParamCommand",
        key="pos",
        value=object_number_close("x", 1800, tolerance=1.0),
    )


@scenario(target="chonsole-native-input")
def chonsole_native_input(run_state: "RunState") -> None:
    """Native input editing: Ctrl+word navigation, selection replacement, and Ctrl+A."""
    run_state.focus()
    run_state.key("Escape")
    run_state.key("Return", delay=Delay.MS_180)
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


@scenario(target="chonsole-native-suggestions")
def chonsole_native_suggestions(run_state: "RunState") -> None:
    """Native suggestions keep their list while Tab-cycling, hovering, and clicking.

    Tab must reach Chonsole before RmlUi can move focus to the editor's search
    field or toolbar. Repeated presses select successive matches from the
    original query, rather than completing the first match and losing the list.
    """
    run_state.focus()
    _open(run_state, "features")  # Features, with search input
    run_state.key("Escape")
    run_state.key("Return", delay=Delay.MS_180)
    run_state.type_text("/h")
    matches = run_state.screenshot("matches")
    width, height = window_size(run_state)
    suggestion_box = chonsole_suggestion_box(width, height)

    run_state.key("Tab")
    first = run_state.screenshot("first-selected")
    run_state.assert_region_pixels(matches, first, suggestion_box, min_changed=100)

    run_state.key("Tab")
    second = run_state.screenshot("second-selected")
    run_state.assert_region_pixels(first, second, suggestion_box, min_changed=100)

    row_x, third_row_y = chonsole_row_point(width, height, 2)
    run_state.move(row_x, third_row_y, delay=Delay.MS_250)
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
    run_state.key("Return", delay=Delay.MS_180)
    run_state.type_text("/set ")
    run_state.move(*chonsole_header_point(width, height))
    unhovered = run_state.screenshot("scroll-start")
    # Two page jumps select the twentieth command. That row is outside the
    # 380dp viewport at the top, so keyboard navigation must scroll the list to
    # reveal it rather than merely changing an invisible selected class.
    run_state.key("Page_Down")
    run_state.key("Page_Down")
    keyboard_scrolled = run_state.screenshot("keyboard-selection-revealed")
    suggestion_rows_at_top = (
        suggestion_box[0],
        suggestion_box[1] + CHONSOLE["header_height"],
        suggestion_box[2],
        suggestion_box[3] - CHONSOLE["header_height"],
    )
    run_state.assert_region_pixels(unhovered, keyboard_scrolled, suggestion_rows_at_top, min_changed=500)

    # Reopen from the top for the independent mouse-wheel/scrollbar checks.
    run_state.key("Escape")
    run_state.key("Return", delay=Delay.MS_180)
    run_state.type_text("/set ")
    run_state.move(*chonsole_header_point(width, height))
    unhovered = run_state.screenshot("scroll-start-reset")
    scrollbar_x, scrollbar_y = chonsole_scrollbar_point(width, height)
    run_state.move(scrollbar_x, scrollbar_y)
    scrollbar_hovered = run_state.screenshot("scrollbar-hovered")
    scrollbar = (
        scrollbar_x - CHONSOLE["scrollbar_width"] // 2,
        suggestion_box[1] + CHONSOLE["header_height"],
        CHONSOLE["scrollbar_width"],
        CHONSOLE["scrollbar_height"],
    )
    run_state.assert_region_pixels(unhovered, scrollbar_hovered, scrollbar, min_changed=40)
    # Hover must colour the scrollbar without changing the suggestions' layout.
    suggestion_content = (*suggestion_box[:2], suggestion_box[2] - 24, suggestion_box[3])
    suggestion_rows = (
        suggestion_content[0],
        suggestion_content[1] + CHONSOLE["header_height"],
        suggestion_content[2],
        suggestion_content[3] - CHONSOLE["header_height"],
    )
    # Captures include the engine cursor; its edge can spill a few pixels into
    # the first row, but a layout reflow would alter thousands of text pixels.
    run_state.assert_region_pixels(unhovered, scrollbar_hovered, suggestion_rows, max_changed=50)

    # Leaving and re-entering the list must not reset either wheel or thumb
    # scrolling. This used to happen because hover rebuilt the suggestion DOM.
    run_state.move(row_x, third_row_y, delay=Delay.MS_250)
    scroll_start = run_state.screenshot("wheel-scroll-start")
    run_state.wheel(row_x, third_row_y, clicks=6, up=False)
    scroll_down = run_state.screenshot("wheel-scroll-down")
    run_state.assert_region_pixels(scroll_start, scroll_down, suggestion_box, min_changed=100)
    run_state.move(int(width * (CHONSOLE["left_fraction"] + CHONSOLE["width_fraction"] + 0.03)), third_row_y)
    run_state.move(row_x, third_row_y)
    scroll_reentered = run_state.screenshot("wheel-scroll-reentered")
    run_state.assert_region_pixels(scroll_down, scroll_reentered, suggestion_box, max_changed=0)

    # Restart at the top, drag the thumb, then prove that re-entering still
    # leaves the dragged position alone.
    run_state.key("Escape")
    run_state.key("Return", delay=Delay.MS_180)
    run_state.type_text("/set ")
    drag_start = run_state.screenshot("drag-scroll-start")
    # The track begins at `scrollbar_x`; its thumb is inset by the track's
    # margin, so drag its centre rather than the track beside it.
    thumb_x = scrollbar_x + CHONSOLE["scrollbar_thumb_inset"]
    run_state.drag(
        thumb_x,
        suggestion_box[1] + CHONSOLE["header_height"] + CHONSOLE["scrollbar_thumb_start_y"],
        thumb_x,
        suggestion_box[1] + CHONSOLE["header_height"] + CHONSOLE["scrollbar_drag_end_y"],
    )
    drag_down = run_state.screenshot("drag-scroll-down")
    run_state.assert_region_pixels(drag_start, drag_down, suggestion_box, min_changed=100)
    run_state.move(int(width * (CHONSOLE["left_fraction"] + CHONSOLE["width_fraction"] + 0.03)), third_row_y)
    run_state.move(scrollbar_x, scrollbar_y)
    drag_reentered = run_state.screenshot("drag-scroll-reentered")
    run_state.assert_region_pixels(drag_down, drag_reentered, suggestion_content, max_changed=0)


@scenario(target="chonsole-native-commands")
def chonsole_native_commands(run_state: "RunState") -> None:
    """Native command completion: engine commands, texture preview, and game-rule values."""
    run_state.focus()
    run_state.key("Escape")
    run_state.key("Return", delay=Delay.MS_180)
    opened = run_state.screenshot("open")
    run_state.type_text("/")
    commands = run_state.screenshot("all-engine-commands")
    width, height = window_size(run_state)
    run_state.assert_region_pixels(
        opened, commands, (width // 4, height // 4, width // 2, height // 2), min_changed=100
    )
    run_state.key_chord(("ctrl",), "a")
    run_state.type_text("/texture ")
    textures = run_state.screenshot("texture-values")
    run_state.assert_region_pixels(
        commands, textures, (width // 4, height // 4, width // 2, height // 2), min_changed=100
    )
    run_state.type_text("$ssmf_specular")
    preview = run_state.screenshot("texture-preview")
    run_state.assert_region_pixels(textures, preview, (0, 0, width // 2, height), min_changed=100)
    run_state.key_chord(("ctrl",), "a")
    run_state.type_text("/gamerules ")
    rules = run_state.screenshot("gamerule-values")
    run_state.assert_region_pixels(preview, rules, (width // 4, height // 4, width // 2, height // 2), min_changed=100)


@scenario(target="chonsole-luaui-reload")
def chonsole_luaui_reload(run_state: "RunState") -> None:
    """Running `/luaui reload` from the rust console.

    Executing a command that runs `Rml::Shutdown()` frees the console's own
    document mid-keypress; hiding that dangling handle right after was a
    use-after-free that aborted the engine. The engine surviving to the
    screenshots below -- a crash would exit it and fail the run on the next capture
    -- is the assertion, plus that the console recreates its context and works
    again after the reload.
    """
    run_state.focus()
    run_state.key("Escape")
    run_state.key("Return", delay=Delay.MS_300)
    run_state.type_text("/luaui reload")
    run_state.screenshot("before-reload")
    # Enter executes it: RmlUi is torn down, then the console hides itself.
    run_state.key("Return", delay=Delay.S_3)
    run_state.screenshot("after-reload")
    # The console must recreate its context and accept input again.
    run_state.key("Return", delay=Delay.MS_400)
    run_state.type_text("recovered")
    run_state.screenshot("console-recovered")


@scenario(crop="dev-console")
def native_dev_console(run_state: "RunState") -> None:
    """The native (Rust) developer console.

    Log content varies run to run, so every golden is taken after `Clear`: an
    empty log is the deterministic state. The toolbar, F8 visibility, and the
    scen_edit status/command strip below it are what these goldens pin down.
    """
    run_state.focus()
    width, height = window_size(run_state)
    # The console is 300dp tall and floats 92dp off the bottom; its toolbar row
    # centres 108px above the window's bottom edge.
    toolbar_y = dev_console_toolbar_y(height)

    run_state.key("F8", delay=Delay.MS_600)  # the harness starts it hidden
    run_state.click(DEV_CONSOLE["clear_x"], toolbar_y, delay=Delay.MS_500)
    run_state.golden("console-cleared")

    # The status strip is not part of the console, but it is positioned directly
    # below it. Its undo/redo/clear controls must enter the same native command
    # path as their editor hotkeys, even when history is empty. Its metrics are
    # deliberately live, so golden only the fixed command half of the strip.
    # RmlUi applies the 34dp icon width to the button's content box; 5dp padding
    # and 1dp borders make its actual hit target 46dp, followed by a 10dp gap.
    # Derive the centres from that real geometry at every E2E resolution.
    run_state.click(*status_button_point(width, height, 0), delay=Delay.MS_400)
    run_state.assert_any_command("UndoCommand")
    run_state.click(*status_button_point(width, height, 1), delay=Delay.MS_400)
    run_state.assert_any_command("RedoCommand")
    run_state.click(*status_button_point(width, height, 2), delay=Delay.MS_400)
    run_state.assert_any_command("ClearUndoRedoCommand")
    run_state.golden("status-bar", crop="status-commands")

    run_state.click(DEV_CONSOLE["problems_x"], toolbar_y, delay=Delay.MS_500)
    run_state.golden("console-problems-on")

    run_state.click(DEV_CONSOLE["problems_x"], toolbar_y, delay=Delay.MS_500)
    run_state.golden("console-problems-off")

    # F8 hides the console, and brings it back.
    run_state.key("F8", delay=Delay.MS_600)
    run_state.golden("console-hidden")

    run_state.key("F8", delay=Delay.MS_600)
    run_state.golden("console-shown")


@scenario()
def native_dev_console_copy(run_state: "RunState") -> None:
    """Selecting log lines and copying them with Ctrl+C.

    The clipboard is read back: the panel's toolbar binds Ctrl+C to Copy, so this
    is also what proves the console wins the key when it has a selection.
    """
    run_state.focus()
    run_state.key("F8", delay=Delay.MS_600)  # the harness starts it hidden
    _width, height = window_size(run_state)
    # The log sits above the toolbar row (108px off the bottom).
    top, bottom = height - 290, height - 140

    # So a stale clipboard from an earlier run cannot pass this.
    run_state.set_clipboard("SENTINEL-NOTHING-WAS-COPIED")

    run_state.drag(
        DEV_CONSOLE["copy_drag_start_x"],
        top,
        DEV_CONSOLE["copy_drag_end_x"],
        bottom,
        steps=10,
    )
    run_state.screenshot("lines-selected")

    run_state.key("ctrl+c", delay=Delay.MS_500)
    copied = run_state.clipboard()
    if not copied.strip() or copied.startswith("SENTINEL"):
        raise AssertionError("Ctrl+C over a console selection copied nothing")

    run_state.key("ctrl+a", delay=Delay.MS_400)
    run_state.key("ctrl+c", delay=Delay.MS_500)
    everything = run_state.clipboard()
    if len(everything) <= len(copied):
        raise AssertionError(f"Ctrl+A did not widen the selection ({len(everything)} <= {len(copied)} chars)")
