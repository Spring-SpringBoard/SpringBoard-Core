use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{FieldSet, Layout};
use crate::sbc::panels::editors::brush::{non_empty, pattern_field, BrushAction, BrushActions};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::NumericField;
use crate::sbc::panels::grid::GridView;
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::states::{BrushKind, BrushSettings, StateRequest};

// Mirrors MetalEditor:Register in scen_edit/view/map/metal_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "metalEditor",
        tab: Tab::Map,
        order: 3,
        caption: "Metal",
        tooltip: "Edit metal map",
        image: "LuaUI/images/scenedit/minerals.png",
        make: || Box::new(MetalEditor::new()),
    }
}

const ACTIONS: &[BrushAction] = &[BrushAction {
    caption: "Set",
    image: "LuaUI/images/scenedit/metal-add.png",
    kind: BrushKind::Metal,
    paint_mode: "",
}];

/// The metal brush.
pub(crate) struct MetalEditor {
    fields: FieldSet,
    actions: BrushActions,
    pattern_grid: GridView,
}

impl MetalEditor {
    pub(crate) fn new() -> Self {
        MetalEditor {
            fields: FieldSet::new(vec![
                pattern_field(),
                Box::new(
                    NumericField::new("size", "Size", 100.0)
                        .min(10.0)
                        .max(5000.0),
                ),
                Box::new(
                    NumericField::new("rotation", "Rotation", 0.0)
                        .min(-360.0)
                        .max(360.0),
                ),
                Box::new(
                    NumericField::new("amount", "Amount", 50.0)
                        .min(0.0)
                        .max(5.1)
                        .decimals(2),
                ),
            ]),
            actions: BrushActions::new(ACTIONS),
            pattern_grid: {
                let mut grid = GridView::new("metal-pattern-grid", 64);
                grid.configure_asset_navigation(
                    "brush_patterns/terrain/",
                    &["png", "jpg", "tga", "dds", "bmp"],
                );
                grid
            },
        }
    }

    fn render_pattern_grid(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        let selected = self.fields.text("patternTexture");
        self.pattern_grid
            .set_selected((!selected.is_empty()).then_some(selected.as_str()));
        self.pattern_grid.render(interface, document)
    }
}

impl Editor for MetalEditor {
    fn generate_rml(&self) -> String {
        let mut h = self.actions.generate_rml();
        h.push_str(&self.fields.generate_rml(&[
            Layout::Section("Pattern"),
            Layout::Raw(self.pattern_grid.container_rml()),
            Layout::Field("size"),
            Layout::Field("rotation"),
            Layout::Field("amount"),
        ]));
        h
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, _models: &mut Models) {}

    fn write_brush(&self, brush: &mut BrushSettings) {
        brush.size = self.fields.number("size");
        brush.rotation = self.fields.number("rotation");
        brush.amount = self.fields.number("amount");
        brush.pattern_texture = non_empty(self.fields.text("patternTexture"));
    }

    fn read_brush(&mut self, brush: &BrushSettings, interface: &NativeInterfaceRef) {
        self.fields.set("size", FieldValue::Number(brush.size));
        self.fields
            .set("rotation", FieldValue::Number(brush.rotation));
        let _ = self.fields.write_values(interface);
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.actions.bind(interface, document)?;
        self.fields
            .bind(interface, document, changes, interactions)?;
        self.pattern_grid.refresh_navigation(interface, document)?;
        self.render_pattern_grid(interface, document)
    }

    fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.fields.write_values(interface)
    }

    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
    ) -> Vec<Box<dyn Command>> {
        self.fields.read(name, interface);
        vec![]
    }

    fn process_drag_end(&mut self, _name: &str) -> Vec<Box<dyn Command>> {
        vec![]
    }

    fn tick(&mut self, interface: &NativeInterfaceRef, document: u64) -> Vec<Box<dyn Command>> {
        self.actions.tick(interface, document);
        for id in self
            .pattern_grid
            .drain_asset_clicks(interface, document)
            .unwrap_or_default()
        {
            self.fields.set("patternTexture", FieldValue::Text(id));
            let _ = self.fields.write_values(interface);
            let _ = self.render_pattern_grid(interface, document);
        }
        vec![]
    }

    fn take_state_request(&mut self) -> Option<StateRequest> {
        self.actions.take_request()
    }

    fn clear_state_selection(&mut self, interface: &NativeInterfaceRef, document: u64) {
        self.actions.clear(interface, document);
    }

    crate::sb_field_editor_methods!();
}
