//! Shared plumbing for the Map tab's brush editors.
//!
//! A brush editor's fields are *brush state*, not engine state: nothing is
//! dispatched when they change. The value is read when the brush paints.
//! Painting itself is still driven by the Lua editing states, so these views
//! currently configure a brush that the native panel does not yet apply.

use crate::sbc::panels::fields::AssetField;

/// Every brush is shaped by a pattern from the same directory.
pub(crate) fn pattern_field() -> Box<AssetField> {
    Box::new(
        AssetField::new("patternTexture", "Pattern", "brush_patterns/terrain")
            .extensions(&[".png", ".jpg", ".tga", ".dds", ".bmp"]),
    )
}

/// The `Editor` methods every brush editor implements identically: fields are
/// local state, so a change dispatches nothing.
macro_rules! brush_editor_boilerplate {
    () => {
        fn bind_fields(
            &mut self,
            interface: &NativeInterfaceRef,
            document: u64,
            changes: &ChangeQueue,
            interactions: &InteractionQueue,
        ) -> Result<(), Error> {
            self.fields.bind(interface, document, changes, interactions)
        }

        fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
            self.fields.write_values(interface)
        }

        /// Brush state: read the DOM so the field holds the new value, and emit
        /// nothing. The brush reads it when it paints.
        fn process_change(
            &mut self,
            name: &str,
            interface: &NativeInterfaceRef,
            _next: &mut u64,
        ) -> Vec<String> {
            self.fields.read(name, interface);
            vec![]
        }

        fn process_drag_end(&mut self, _name: &str, _next: &mut u64) -> Vec<String> {
            vec![]
        }

        fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
            self.fields.drag(name, dx, interface)
        }

        fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
            self.fields.drag_end(name, interface)
        }

        fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
            self.fields.begin_edit(name, interface)
        }

        fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
            self.fields.cancel_edit(name, interface)
        }

        fn field_value(&self, name: &str) -> FieldValue {
            self.fields.value(name)
        }

        fn set_field_value(
            &mut self,
            name: &str,
            value: FieldValue,
            interface: &NativeInterfaceRef,
        ) {
            self.fields
                .set($crate::sbc::panels::editor_base::resolve_base(name), value);
            let _ = self.fields.write_values(interface);
        }

        fn field_asset(&self, name: &str) -> Option<(String, Vec<String>)> {
            self.fields.asset_info(name)
        }
    };
}

pub(crate) use brush_editor_boilerplate;
