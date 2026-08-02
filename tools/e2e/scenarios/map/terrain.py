"""Map -> Terrain and heightmap scenarios."""

from pathlib import Path
from typing import TYPE_CHECKING

from e2e.driver.timing import Delay
from e2e.scenarios.helpers.camera import zoom_map
from e2e.scenarios.helpers.geometry import (
    MAP_ACTIONS,
    MAP_TERRAIN_BRUSHES,
    PARK_PANEL,
    TAB_X,
    TAB_Y,
    editor_point,
    panel_left,
    panel_point,
    window_size,
)
from e2e.scenarios.helpers.registry import scenario

from .common import (
    MAP_SHIMMER,
    MAP_STROKE_PIXELS,
    STROKE_MIN_DABS,
    STROKE_STEP_DELAY,
    STROKE_STEPS,
    TERRAIN_PATTERN_PATH,
)

if TYPE_CHECKING:
    from e2e.driver.state import RunState


@scenario()
def pattern_preview(run_state: "RunState") -> None:
    """A selected Terrain/Add pattern is visibly projected under the cursor.

    The test does not paint. It arms Add with no pattern, then selects one and
    checks that the active brush gains its textured ground footprint. The map is
    framed through the control API so this scenario does not exercise camera
    wheel input as a side effect.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    map_region = (0, 0, width - 500, height - 92)
    point = (width // 3, height // 2)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.FRAME)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.READY)
    terrain = run_state.control.editor("heightmapEditor")
    zoom_map(run_state, factor=0.25, point=point)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=Delay.DIALOG)
    run_state.move(*point, delay=Delay.SETTLE)
    before = run_state.screenshot("armed-without-pattern")
    terrain.set("patternTexture", TERRAIN_PATTERN_PATH)
    run_state.move(*point, delay=Delay.FRAME)
    preview = run_state.screenshot("pattern-preview")
    run_state.assert_region_pixels(before, preview, map_region, min_changed=1_000)


@scenario()
def terrain_stationary_hold(run_state: "RunState") -> None:
    """Terrain Add keeps dabbing while held at one grounded cursor position.

    This is deliberately not a sweep: a moving pointer can mask a failed held
    update. A press waits through the inherited initial delay while remaining at
    the same point, then must produce several terrain commands in one stroke.
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    point = (width // 3, height // 2)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.FRAME)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.READY)
    terrain = run_state.control.editor("heightmapEditor")
    terrain.set("patternTexture", TERRAIN_PATTERN_PATH)
    run_state.click(*panel_point(left, MAP_ACTIONS["terrain_add"]), delay=Delay.SETTLE)
    zoom_map(run_state, factor=0.5, point=point)

    before = run_state.assert_command_at_least("TerrainShapeModifyCommand", 0)
    run_state.press(*point)
    # No cursor movement: wait for the actual repeat commands while keeping
    # the button down instead of sleeping a guessed duration.
    run_state.move(*point)
    run_state.wait_for_command_at_least("TerrainShapeModifyCommand", before + STROKE_MIN_DABS)
    run_state.release(*point, delay=Delay.DIALOG)
    run_state.assert_command_at_least("TerrainShapeModifyCommand", before + STROKE_MIN_DABS)
    run_state.screenshot("stationary-stroke-complete")


@scenario()
def heightmap(run_state: "RunState") -> None:
    """Map -> Terrain: sweep each brush (Add, Set, Smooth) as a held stroke and
    undo/redo one.

    A stroke, not a click: the button goes down, the pointer sweeps across the
    map, and the button comes up at the far end -- so this covers the repeat
    timer and the streaming undo group, not merely "the command class exists".
    """
    run_state.focus()
    left = panel_left(run_state)
    width, height = window_size(run_state)
    map_region = (0, 0, width - 500, height - 92)

    def assert_map_pixels(before: Path, after: Path, **bounds: int) -> None:
        run_state.assert_region_pixels(before, after, map_region, **bounds)

    def stroke(x: int, y: int, dx: int, dy: int, command: str, before: int) -> None:
        """Hold and sweep. `move` between press and release is what the brush
        sees as motion; the dabs land along the way."""
        run_state.press(x, y)
        for i in range(1, STROKE_STEPS + 1):
            run_state.move(
                round(x + dx * i / STROKE_STEPS),
                round(y + dy * i / STROKE_STEPS),
                delay=STROKE_STEP_DELAY,
            )
        run_state.release(x + dx, y + dy)
        # Shape Modify publishes each repeat while held. Set and Smooth keep
        # their dabs in the active stroke and commit them on primary release.
        # Wait for all three here: the release queues the latter two, and a
        # plain count would race the command drain on a busy shared session.
        run_state.wait_for_command_at_least(command, before + STROKE_MIN_DABS)

    run_state.click(left + TAB_X["map"], TAB_Y, delay=Delay.FRAME)
    run_state.click(*editor_point(left, "map", "terrain"), delay=Delay.READY)
    terrain = run_state.control.editor("heightmapEditor")
    run_state.screenshot("terrain-open")
    terrain.set("patternTexture", TERRAIN_PATTERN_PATH)

    # The default camera sits far enough out that a 100-unit brush is a smudge a
    # few pixels across -- the stroke lands, but nothing in the shot says so.
    # Frame the map through the control API and paint with a brush the size of
    # the hill it is meant to raise, so each stroke is plainly visible in
    # `stroke-*.png` and the diffs mean something.
    zoom_map(run_state, factor=0.5, point=(width // 3, height // 2))
    terrain.size = 400.0
    # Shape Modify applies a signed delta. Keep it representative: an enormous
    # strength makes the outcome depend on a few milliseconds of stroke timing
    # and can drive the terrain beyond what the engine handles robustly.
    terrain.strength = 10.0
    terrain.height = 80.0
    run_state.screenshot("brush-settings")

    # Each brush is a held stroke. Add uses the centre; Set and Smooth use a
    # second, still-flat patch. After a large Add stroke the camera can be
    # inside the raised terrain, making the old centre ray miss the ground and
    # turning the Set/Smooth part of this test into a false negative.
    stroke_points = {
        "add": (width // 3, height // 2),
        "set": (width // 3, height * 3 // 4),
        "smooth": (width // 3, height * 3 // 4),
    }
    for action, name, command in MAP_TERRAIN_BRUSHES:
        run_state.click(*panel_point(left, MAP_ACTIONS[action]), delay=Delay.DIALOG)
        run_state.move(*panel_point(left, PARK_PANEL), delay=Delay.SETTLE)
        before_shot = run_state.screenshot(f"before-{name}")
        before = run_state.assert_command_at_least(command, 0)

        x, y = stroke_points[name]
        if run_state.control.camera.trace_screen_ray(x, y)["hit_type"] != 3:
            raise AssertionError(f"{name} stroke start does not hit ground at {(x, y)}")
        stroke(x, y, 160, 90, command, before)
        run_state.move(*panel_point(left, PARK_PANEL), delay=Delay.DIALOG)
        after_shot = run_state.screenshot(f"stroke-{name}")

        run_state.assert_command_at_least(command, before + STROKE_MIN_DABS)
        if not any(f'shape_name: "{TERRAIN_PATTERN_PATH}"' in line for line in run_state.engine_log()):
            raise AssertionError("terrain brush did not receive the selected full VFS texture path")
        # The commands reaching the bridge is not the point: the terrain has to
        # actually change. A brush whose settings make it a no-op sends a full
        # stroke of commands and moves nothing.
        assert_map_pixels(before_shot, after_shot, min_changed=MAP_STROKE_PIXELS)

    # Undo/redo the last stroke. Each stroke is one group, so one undo takes the
    # whole smooth back off, however many dabs it was.
    #
    # AbstractState:KeyPress drops hotkeys while a mouse button still reads as
    # down, so let the stroke's release land before undoing.
    swept = run_state.screenshot("swept")
    run_state.control.commands["UndoCommand"]()
    run_state.control.wait_for_update()
    run_state.assert_any_command("UndoCommand")
    undone = run_state.screenshot("undone")
    assert_map_pixels(swept, undone, min_changed=100)
    run_state.control.commands["RedoCommand"]()
    run_state.control.wait_for_update()
    run_state.assert_any_command("RedoCommand")
    redone = run_state.screenshot("redone")
    assert_map_pixels(undone, redone, min_changed=100)
    # Redo puts the same terrain back. Not bit-for-bit: the map itself does not
    # render identically frame to frame, so allow its shimmer and nothing more.
    assert_map_pixels(swept, redone, max_changed=MAP_SHIMMER)
