//! The pointer while a numeric field is being dragged.
//!
//! A port of what `NumericField:__StartDragging` / `__StopDragging` do in Lua:
//! swap the cursor for an empty one while the value changes. The engine owns
//! pointer pinning; this helper only owns cursor presentation.

use spring_native::prelude::NativeInterfaceRef;

/// Lua assigns a cursor named "empty" and selects it; the name is the asset.
const EMPTY_CURSOR: &str = "empty";

#[derive(Default)]
pub(crate) struct DragCursor {
    assigned: bool,
}

impl DragCursor {
    pub(crate) fn begin(&mut self, interface: &NativeInterfaceRef) {
        let ctrl = interface.unsynced_ctrl();
        if !self.assigned {
            // Lua does the same on first use: the cursor has to exist before it
            // can be selected.
            let _ = ctrl.assign_mouse_cursor(EMPTY_CURSOR, EMPTY_CURSOR, true, true);
            self.assigned = true;
        }
        let _ = ctrl.set_mouse_cursor(EMPTY_CURSOR, 1.0);
    }

    /// Re-assert the empty cursor while a drag is active.
    pub(crate) fn reassert(&self, interface: &NativeInterfaceRef) {
        // Re-assert it every tick: the engine syncs the cursor to whatever RmlUi
        // is hovering on each update, so setting it once at dragstart is undone
        // on the very next frame.
        let _ = interface
            .unsynced_ctrl()
            .set_mouse_cursor(EMPTY_CURSOR, 1.0);
    }

    pub(crate) fn end(&mut self, interface: &NativeInterfaceRef) {
        // An empty name restores the engine's own cursor, as Lua's bare
        // `SB.SetMouseCursor()` does.
        let _ = interface.unsynced_ctrl().set_mouse_cursor("", 1.0);
    }

    /// End an interrupted drag without moving the cursor back into the panel.
    /// A new press is an explicit user decision about where the pointer is, so
    /// preserving that location avoids turning a right-click on the map into a
    /// surprise cursor teleport.
    pub(crate) fn cancel(&mut self, interface: &NativeInterfaceRef) {
        let _ = interface.unsynced_ctrl().set_mouse_cursor("", 1.0);
    }
}
