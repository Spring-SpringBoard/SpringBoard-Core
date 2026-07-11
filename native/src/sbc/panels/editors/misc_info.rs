use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{envelope_with, resolve_base, FieldSet, Layout};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::StringField;
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::project::ScenarioInfoManager;

// Mirrors ScenarioInfoView:Register in scen_edit/view/general/scenario_info_view.lua.
inventory::submit! {
    EditorSpec {
        name: "scenarioInfoView",
        tab: Tab::Misc,
        order: 0,
        caption: "Info",
        tooltip: "Edit project info",
        image: "LuaUI/images/scenedit/info.png",
        make: || Box::new(ScenarioInfoView::new()),
    }
}

const FIELDS: &[&str] = &["name", "description", "version", "author"];

/// Project metadata. Unlike the Env views this reads the project model, not the
/// engine, and sends the whole record: `SetScenarioInfoCommand` merges a partial
/// patch, but Lua sends all four fields together.
pub(crate) struct ScenarioInfoView {
    fields: FieldSet,
}

impl ScenarioInfoView {
    pub(crate) fn new() -> Self {
        ScenarioInfoView {
            fields: FieldSet::new(vec![
                Box::new(StringField::new("name", "Name", "")),
                Box::new(StringField::new("description", "Description", "")),
                Box::new(StringField::new("version", "Version", "")),
                Box::new(StringField::new("author", "Author", "")),
            ]),
        }
    }

    fn info_envelope(&self, next: &mut u64) -> Vec<String> {
        vec![envelope_with(
            "SetScenarioInfoCommand",
            next,
            "data",
            serde_json::json!({
                "name": self.fields.text("name"),
                "description": self.fields.text("description"),
                "version": self.fields.text("version"),
                "author": self.fields.text("author"),
            }),
        )]
    }
}

impl Editor for ScenarioInfoView {
    fn generate_rml(&self) -> String {
        self.fields.generate_rml(&[
            Layout::Field("name"),
            Layout::Field("description"),
            Layout::Field("version"),
            Layout::Field("author"),
        ])
    }

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

    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
        next: &mut u64,
    ) -> Vec<String> {
        let base = resolve_base(name).to_string();
        if !FIELDS.contains(&base.as_str()) {
            return vec![];
        }
        self.fields.read(&base, interface);
        self.info_envelope(next)
    }

    fn process_drag_end(&mut self, _name: &str, _next: &mut u64) -> Vec<String> {
        vec![]
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, models: &mut Models) {
        let info = models.get::<ScenarioInfoManager>().serialize();
        self.fields.set("name", FieldValue::Text(info.name));
        self.fields
            .set("description", FieldValue::Text(info.description));
        self.fields.set("version", FieldValue::Text(info.version));
        self.fields.set("author", FieldValue::Text(info.author));
    }

    crate::sb_field_editor_methods!();
}
