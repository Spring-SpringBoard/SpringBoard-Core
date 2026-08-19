"""The developer console."""

from typing import TYPE_CHECKING

from e2e.driver.timing import Delay

if TYPE_CHECKING:
    from e2e.driver.state import RunState

from .helpers.geometry import (
    DEV_CONSOLE,
    dev_console_toolbar_y,
    status_button_point,
    window_size,
)
from .helpers.registry import scenario


@scenario(target="developer-console", crop="dev-console")
def developer_console(run_state: "RunState") -> None:
    """The developer console.

    Log content varies run to run, so goldens start after `Clear`. Injected
    echo lines exercise the problems filter with known error/warning/info
    content. The toolbar, F8 visibility, and the scen_edit status/command
    strip below it are what these goldens pin down.
    """
    run_state.focus()
    width, height = window_size(run_state)
    toolbar_y = dev_console_toolbar_y(height)

    run_state.key("F8", delay=Delay.DIALOG)  # the harness starts it hidden
    run_state.click(DEV_CONSOLE["clear_x"], toolbar_y, delay=Delay.DIALOG)
    run_state.golden("console-cleared")

    run_state.click(*status_button_point(width, height, 0), delay=Delay.SETTLE)
    run_state.assert_any_command("UndoCommand")
    run_state.click(*status_button_point(width, height, 1), delay=Delay.SETTLE)
    run_state.assert_any_command("RedoCommand")
    run_state.click(*status_button_point(width, height, 2), delay=Delay.READY)
    run_state.assert_any_command("ClearUndoRedoCommand")
    run_state.golden("status-bar", crop="status-commands")

    run_state.click(DEV_CONSOLE["clear_x"], toolbar_y, delay=Delay.DIALOG)
    run_state.control.echo("Scenario loaded successfully")
    run_state.control.echo("Terrain initialized for map Spring Valley")
    run_state.control.echo("Error: failed to load texture normals.dds", level=50)
    run_state.control.echo("Warning: deprecated feature used in widget", level=40)
    run_state.control.echo("Objects placed: 42 units, 18 features")
    run_state.control.echo("Error: shader compilation failed for water.glsl", level=50)
    run_state.control.echo("Lighting pass completed in 12ms")
    run_state.control.wait_for_update()

    run_state.click(DEV_CONSOLE["problems_x"], toolbar_y, delay=Delay.DIALOG)
    run_state.golden("console-problems-on")

    run_state.click(DEV_CONSOLE["problems_x"], toolbar_y, delay=Delay.DIALOG)
    run_state.golden("console-problems-off")

    run_state.key("F8", delay=Delay.DIALOG)
    run_state.golden("console-hidden")

    run_state.key("F8", delay=Delay.DIALOG)
    run_state.golden("console-shown")
    run_state.key("F8", delay=Delay.FRAME)


@scenario(target="developer-console-copy")
def developer_console_copy(run_state: "RunState") -> None:
    """Selecting log lines and copying them with Ctrl+C."""
    run_state.focus()
    run_state.key("F8", delay=Delay.DIALOG)  # the harness starts it hidden
    _width, height = window_size(run_state)
    top, bottom = height - 290, height - 140

    run_state.set_clipboard("SENTINEL-NOTHING-WAS-COPIED")

    run_state.drag(
        DEV_CONSOLE["copy_drag_start_x"],
        top,
        DEV_CONSOLE["copy_drag_end_x"],
        bottom,
        steps=10,
    )
    run_state.screenshot("lines-selected")

    run_state.key("ctrl+c", delay=Delay.DIALOG)
    copied = run_state.clipboard()
    if not copied.strip() or copied.startswith("SENTINEL"):
        raise AssertionError("Ctrl+C over a console selection copied nothing")

    run_state.key("ctrl+a", delay=Delay.SETTLE)
    run_state.key("ctrl+c", delay=Delay.DIALOG)
    everything = run_state.clipboard()
    if len(everything) <= len(copied):
        raise AssertionError(f"Ctrl+A did not widen the selection ({len(everything)} <= {len(copied)} chars)")
