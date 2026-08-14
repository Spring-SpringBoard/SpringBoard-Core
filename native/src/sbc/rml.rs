use spring_native::prelude::NativeInterfaceRef;

pub(crate) mod rows;

const FONT: &str = "fonts/Poppins-Regular.ttf";

const CURSOR_ALIASES: [(&str, &str); 7] = [
    ("default", "cursornormal"),
    ("pointer", "cursornormal"),
    ("move", "uimove"),
    ("nesw-resize", "uiresized2"),
    ("nwse-resize", "uiresized1"),
    ("ns-resize", "uiresizev"),
    ("ew-resize", "uiresizeh"),
];

pub(crate) fn setup(interface: &NativeInterfaceRef) {
    let rml = interface.rml_ui();
    if let Err(err) = rml.load_font_face(FONT, true, None) {
        log::warn!("rml: could not load {FONT}: {err:?}");
    }
    for (rml_name, recoil_name) in CURSOR_ALIASES {
        let _ = rml.set_mouse_cursor_alias(rml_name, recoil_name);
    }
}

pub(crate) fn context_is_alive(
    interface: &NativeInterfaceRef,
    name: &str,
    context: Option<u64>,
) -> bool {
    let Some(context) = context else {
        return false;
    };
    interface
        .rml_ui()
        .get_context(name)
        .is_ok_and(|(handle, exists)| exists && handle == context)
}

pub(crate) fn element_by_id(interface: &NativeInterfaceRef, root: u64, id: &str) -> Option<u64> {
    interface
        .rml_ui()
        .element_get_element_by_id(root, id)
        .ok()
        .and_then(|(handle, exists)| exists.then_some(handle))
}
