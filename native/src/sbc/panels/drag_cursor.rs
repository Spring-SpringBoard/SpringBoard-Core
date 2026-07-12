//! The pointer while a numeric field is being dragged.
//!
//! A port of what `NumericField:__StartDragging` / `__StopDragging` do in Lua:
//! swap the cursor for an empty one and pin the pointer to where the drag began,
//! warping it back after every move. The value then follows the mouse for as far
//! as the user cares to push it, and the pointer never runs off the field, off
//! the panel, or off the screen -- the way every content-creation tool behaves.
//!
//! The pointer is restored to the anchor when the drag ends, so the cursor is
//! exactly where the user left it.

use spring_native::prelude::NativeInterfaceRef;

/// Lua assigns a cursor named "empty" and selects it; the name is the asset.
const EMPTY_CURSOR: &str = "empty";

#[derive(Default)]
pub(crate) struct DragCursor {
    /// Where the drag began, in engine mouse coordinates. The pointer is warped
    /// back here every tick, so it never actually moves.
    anchor: Option<(i32, i32)>,
    assigned: bool,
}

impl DragCursor {
    /// Where the pointer is pinned. The drag's delta is measured from here,
    /// because the pointer is put back on it after every move.
    pub(crate) fn anchor_x(&self) -> Option<f32> {
        self.anchor.map(|(x, _)| x as f32)
    }

    pub(crate) fn begin(&mut self, interface: &NativeInterfaceRef) {
        let Ok(mouse) = interface.input().get_mouse_state() else {
            return;
        };
        self.anchor = Some((mouse.x as i32, mouse.y as i32));

        let ctrl = interface.unsynced_ctrl();
        if !self.assigned {
            // Lua does the same on first use: the cursor has to exist before it
            // can be selected.
            let _ = ctrl.assign_mouse_cursor(EMPTY_CURSOR, EMPTY_CURSOR, true, true);
            self.assigned = true;
        }
        let _ = ctrl.set_mouse_cursor(EMPTY_CURSOR, 1.0);
    }

    /// Pin the pointer back to the anchor. Called after the value has taken the
    /// movement, so the motion is consumed rather than lost.
    pub(crate) fn hold(&self, interface: &NativeInterfaceRef) {
        let Some((x, y)) = self.anchor else {
            return;
        };
        let ctrl = interface.unsynced_ctrl();
        let _ = ctrl.warp_mouse(x, y);
        // Re-assert it every tick: the engine syncs the cursor to whatever RmlUi
        // is hovering on each update, so setting it once at dragstart is undone
        // on the very next frame.
        let _ = ctrl.set_mouse_cursor(EMPTY_CURSOR, 1.0);
    }

    pub(crate) fn end(&mut self, interface: &NativeInterfaceRef) {
        let ctrl = interface.unsynced_ctrl();
        if let Some((x, y)) = self.anchor.take() {
            let _ = ctrl.warp_mouse(x, y);
        }
        // An empty name restores the engine's own cursor, as Lua's bare
        // `SB.SetMouseCursor()` does.
        let _ = ctrl.set_mouse_cursor("", 1.0);
    }
}
