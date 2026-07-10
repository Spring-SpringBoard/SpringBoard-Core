//! RmlUi DOM helpers shared by the native panel and the dev console.

use spring_native::prelude::NativeInterfaceRef;

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
