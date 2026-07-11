//! Small engine-facing helpers shared by [`super::run`] and [`super::project`].

use spring_native::prelude::NativeInterfaceRef;

/// The `(name, version)` of the game the editor is running, for the reload
/// command's start script.
pub(super) fn game_id(interface: &NativeInterfaceRef) -> (String, String) {
    let Ok(info) = interface.game().get_game_mod_info() else {
        return (String::new(), String::new());
    };
    // SAFETY: the engine owns these strings for the lifetime of the call; we copy
    // them out immediately.
    unsafe { (cstr(info.gameName), cstr(info.gameVersion)) }
}

/// Copy a C string the engine handed back, or empty if null.
unsafe fn cstr(ptr: *const std::os::raw::c_char) -> String {
    if ptr.is_null() {
        String::new()
    } else {
        std::ffi::CStr::from_ptr(ptr).to_string_lossy().into_owned()
    }
}

/// The map's height extremes, as an import default when the user hasn't given
/// explicit min/max heights.
pub(super) fn ground_extremes(interface: &NativeInterfaceRef) -> (f32, f32) {
    interface
        .terrain()
        .get_ground_height(0.0, 0.0)
        .map(|h| (h, h))
        .unwrap_or((0.0, 100.0))
}

/// A deterministic pseudo-random for blank-map seeding (avoids engine map-cache
/// collisions, the same trick as Lua's `math.random(1, 1000000)`).
pub(super) fn rand_u32() -> u32 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| (d.subsec_nanos() % 1_000_000) + 1)
        .unwrap_or(1)
}
