//! RmlUi DOM helpers shared by the native panel and the dev console.

use spring_native::prelude::NativeInterfaceRef;

pub(crate) mod rows;

const FONT: &str = "fonts/Poppins-Regular.ttf";

/// Weights the theme asks for. RmlUi resolves `font-weight` against the faces that were actually
/// registered and warns, per element, per frame, when it cannot find one -- and five rules across
/// the console and panel themes ask for bold.
///
/// Only the regular face ships, so bold is registered from the same file. That is a real
/// compromise and worth stating: text styled bold renders at regular weight rather than
/// synthesising a heavier one. The alternatives were to drop `font-weight: bold` from the themes,
/// which loses the distinction the rules were written for, or to add a second TTF.
const WEIGHTS: [Option<i32>; 2] = [None, Some(700)];

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
    for weight in WEIGHTS {
        if let Err(err) = rml.load_font_face(FONT, true, weight) {
            log::warn!("rml: could not load {FONT} at weight {weight:?}: {err:?}");
        }
    }
    for (rml_name, recoil_name) in CURSOR_ALIASES {
        let _ = rml.set_mouse_cursor_alias(rml_name, recoil_name);
    }
}

pub(crate) fn create_context(
    interface: &NativeInterfaceRef,
    name: &str,
) -> Result<(u64, bool), spring_native::prelude::Error> {
    let context = interface.rml_ui().create_context(name)?;
    // RmlGui tears down its global font registry during LuaUI reload while
    // the native module remains loaded. Context creation is the first safe
    // point after that teardown at which the Rust side can reinstall assets.
    setup(interface);
    Ok(context)
}

/// Whether `context` is still the live context registered under `name`.
///
/// `luaui reload` runs `RmlGui::Shutdown()` → `Rml::Shutdown()`, which destroys
/// *every* context, plugin-owned ones included; the engine cannot keep our
/// pointers alive across it. Any handle cached from before is dangling, and
/// touching one is a use-after-free. Every view that caches a context handle
/// must revalidate it by name before using it, and drop its handles when this
/// returns false.
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

/// Look up an element by id within a document or element.
pub(crate) fn element_by_id(interface: &NativeInterfaceRef, root: u64, id: &str) -> Option<u64> {
    interface
        .rml_ui()
        .element_get_element_by_id(root, id)
        .ok()
        .and_then(|(handle, exists)| exists.then_some(handle))
}

/// Escape text for safe inclusion in RML.
pub(crate) fn escape_rml(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn escaping_protects_markup_characters() {
        assert_eq!(escape_rml(r#"<a> & </a>"#), "&lt;a&gt; &amp; &lt;/a&gt;");
    }

    #[test]
    fn ampersands_are_escaped_before_the_entities_they_introduce() {
        // Escaping `<` first would leave `&amp;lt;` here.
        assert_eq!(escape_rml("&lt;"), "&amp;lt;");
    }
}
