//! The mouse cursor while an editing state is active.

use std::cell::RefCell;
use std::collections::HashSet;

use spring_native::prelude::NativeInterfaceRef;

thread_local! {
    static CURSOR: RefCell<Cursor> = RefCell::new(Cursor::default());
}

#[derive(Default)]
struct Cursor {
    wanted: Option<String>,
    assigned: HashSet<String>,
    interface_hidden: bool,
}

/// `None` hands the cursor back to the engine.
pub(crate) fn set(interface: &NativeInterfaceRef, name: Option<&str>) {
    CURSOR.with(|cursor| {
        let mut cursor = cursor.borrow_mut();
        cursor.wanted = name.map(str::to_string);

        let ctrl = interface.unsynced_ctrl();
        let Some(name) = name else {
            let _ = ctrl.set_mouse_cursor("", 1.0);
            return;
        };
        // These are SpringBoard's own images (Anims/drag_0.png), so they must be
        // assigned before they can be selected.
        if cursor.assigned.insert(name.to_string()) {
            let _ = ctrl.assign_mouse_cursor(name, name, true, true);
        }
        let _ = ctrl.set_mouse_cursor(name, 1.0);
    });
}

/// Must run every frame: the engine puts its own cursor back each time it draws.
pub(crate) fn reassert(interface: &NativeInterfaceRef) {
    CURSOR.with(|cursor| {
        let mut cursor = cursor.borrow_mut();
        // Clean captures hide the interface, including the editing state's pointer.
        if interface.display().is_guihidden().unwrap_or(false) {
            if cursor.assigned.insert(String::from("empty")) {
                let _ = interface
                    .unsynced_ctrl()
                    .assign_mouse_cursor("empty", "empty", true, true);
            }
            let _ = interface.unsynced_ctrl().set_mouse_cursor("empty", 1.0);
            cursor.interface_hidden = true;
            return;
        }
        if cursor.interface_hidden {
            cursor.interface_hidden = false;
            let _ = interface.unsynced_ctrl().set_mouse_cursor("", 1.0);
        }
        if let Some(name) = cursor.wanted.as_deref() {
            let _ = interface.unsynced_ctrl().set_mouse_cursor(name, 1.0);
        }
    });
}
