use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{FieldSet, Layout};
use crate::sbc::panels::editors::brush::{non_empty, pattern_field, BrushAction, BrushActions};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::NumericField;
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::states::{BrushKind, BrushSettings, StateRequest};

// Mirrors GrassEditor:Register in scen_edit/view/map/grass_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "grassEditor",
        tab: Tab::Map,
        order: 4,
        caption: "Grass",
        tooltip: "Edit grass",
        image: "LuaUI/images/scenedit/grass.png",
        make: || Box::new(GrassEditor::new()),
    }
}

const ACTIONS: &[BrushAction] = &[BrushAction {
    caption: "Add",
    image: "LuaUI/images/scenedit/grass-add.png",
    kind: BrushKind::Grass,
    paint_mode: "",
}];

/// The grass brush. `grassDetail` is an engine config value rather than brush
/// state, so it is applied straight away, as Lua does with `SetConfigInt`.
pub(crate) struct GrassEditor {
    fields: FieldSet,
    actions: BrushActions,
}

impl GrassEditor {
    pub(crate) fn new() -> Self {
        GrassEditor {
            fields: FieldSet::new(vec![
                pattern_field(),
                Box::new(
                    NumericField::new("grassDetail", "Detail", 5.0)
                        .min(0.0)
                        .max(10.0),
                ),
                Box::new(
                    NumericField::new("size", "Size", 100.0)
                        .min(40.0)
                        .max(2000.0),
                ),
                Box::new(
                    NumericField::new("rotation", "Rotation", 0.0)
                        .min(-360.0)
                        .max(360.0),
                ),
            ]),
            actions: BrushActions::new(ACTIONS),
        }
    }

    fn apply_grass_detail(&self, interface: &NativeInterfaceRef) {
        if let FieldValue::Number(value) = self.fields.value("grassDetail") {
            let _ = interface
                .config()
                .set_config_int("GrassDetail", value.ceil() as i32, true);
        }
    }
}

impl Editor for GrassEditor {
    fn generate_rml(&self) -> String {
        let mut h = self.actions.generate_rml();
        h.push_str(&self.fields.generate_rml(&[
            Layout::Field("patternTexture"),
            Layout::Field("grassDetail"),
            Layout::Field("size"),
            Layout::Field("rotation"),
        ]));
        h
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, _models: &mut Models) {
        if let Ok((detail, true)) = interface.config().get_config_int("GrassDetail", Some(5)) {
            self.fields
                .set("grassDetail", FieldValue::Number(detail as f32));
        }
    }

    fn write_brush(&self, brush: &mut BrushSettings) {
        brush.size = self.fields.number("size");
        brush.rotation = self.fields.number("rotation");
        brush.pattern_texture = non_empty(self.fields.text("patternTexture"));
    }

    fn read_brush(&mut self, brush: &BrushSettings, interface: &NativeInterfaceRef) {
        self.fields.set("size", FieldValue::Number(brush.size));
        self.fields
            .set("rotation", FieldValue::Number(brush.rotation));
        let _ = self.fields.write_values(interface);
    }

    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
        _next: &mut u64,
    ) -> Vec<String> {
        self.fields.read(name, interface);
        if name == "grassDetail" {
            self.apply_grass_detail(interface);
        }
        vec![]
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.actions.bind(interface, document)?;
        self.fields.bind(interface, document, changes, interactions)
    }

    fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.fields.write_values(interface)
    }

    fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        _next: &mut u64,
    ) -> Vec<String> {
        self.actions.tick(interface, document);
        vec![]
    }

    fn take_state_request(&mut self) -> Option<StateRequest> {
        self.actions.take_request()
    }

    fn process_drag_end(&mut self, _name: &str, _next: &mut u64) -> Vec<String> {
        vec![]
    }

    fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
        self.fields.drag(name, dx, interface)
    }

    /// The config write happens on release; one per drag step would be wasteful.
    fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
        let handled = self.fields.drag_end(name, interface);
        if name == "grassDetail" {
            self.apply_grass_detail(interface);
        }
        handled
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

    fn set_field_value(&mut self, name: &str, value: FieldValue, interface: &NativeInterfaceRef) {
        self.fields.set(name, value);
        let _ = self.fields.write_values(interface);
    }

    fn field_asset(&self, name: &str) -> Option<(String, Vec<String>)> {
        self.fields.asset_info(name)
    }
}
