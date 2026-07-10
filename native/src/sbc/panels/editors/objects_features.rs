use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editors::object_defs::{DefKind, ObjectDefsView};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::states::StateRequest;

// Mirrors FeatureDefsView:Register in scen_edit/view/object/object_defs_view.lua.
inventory::submit! {
    EditorSpec {
        name: "featureDefsView",
        tab: Tab::Objects,
        order: 1,
        caption: "Features",
        tooltip: "Place features",
        image: "LuaUI/images/scenedit/beech.png",
        make: || Box::new(FeatureDefsView::new()),
    }
}

pub(crate) struct FeatureDefsView {
    defs: ObjectDefsView,
}

impl FeatureDefsView {
    pub(crate) fn new() -> Self {
        FeatureDefsView {
            defs: ObjectDefsView::new(DefKind::Feature),
        }
    }
}

impl Editor for FeatureDefsView {
    fn generate_rml(&self) -> String {
        self.defs.generate_rml()
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.defs.bind(interface, document, changes, interactions)
    }

    fn write_field_values(&self, _interface: &NativeInterfaceRef) -> Result<(), Error> {
        Ok(())
    }

    fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        _next: &mut u64,
    ) -> Vec<String> {
        let _ = self.defs.tick(interface, document);
        vec![]
    }

    /// Picking a definition arms the next map click to place it.
    fn take_state_request(&mut self) -> Option<StateRequest> {
        self.defs
            .take_selection_change()
            .map(StateRequest::AddFeature)
    }

    fn process_change(
        &mut self,
        _name: &str,
        _interface: &NativeInterfaceRef,
        _next: &mut u64,
    ) -> Vec<String> {
        self.defs.mark_search_dirty();
        vec![]
    }

    fn process_drag_end(&mut self, _name: &str, _next: &mut u64) -> Vec<String> {
        vec![]
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, _models: &mut Models) {}

    fn drag_field(&mut self, _name: &str, _dx: f32, _interface: &NativeInterfaceRef) -> bool {
        false
    }

    fn drag_end_field(&mut self, _name: &str, _interface: &NativeInterfaceRef) -> bool {
        false
    }

    fn begin_edit_field(&mut self, _name: &str, _interface: &NativeInterfaceRef) {}

    fn cancel_edit_field(&mut self, _name: &str, _interface: &NativeInterfaceRef) {}

    fn field_value(&self, _name: &str) -> FieldValue {
        FieldValue::Text(self.defs.selected().unwrap_or_default().to_string())
    }

    fn set_field_value(&mut self, _name: &str, _value: FieldValue, _iface: &NativeInterfaceRef) {}

    fn field_asset(&self, _name: &str) -> Option<(String, Vec<String>)> {
        None
    }
}
