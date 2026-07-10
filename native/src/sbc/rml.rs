//! RmlUi DOM helpers shared by the native panel and the dev console.

use spring_native::prelude::NativeInterfaceRef;

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
