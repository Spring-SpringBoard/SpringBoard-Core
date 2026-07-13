//! Every field control the panel has, in one place -- a kitchen sink.
//!
//! It exists to be looked at and driven: a screenshot of this editor is a
//! screenshot of the whole control set, and a scenario that walks it exercises
//! every field type without needing a real editor that happens to use one. Each
//! commit logs the value it produced, so what the DOM sent is readable in the
//! run's log.
//!
//! Only in the Dev tab, which is off unless `SBC_DEV_PANEL=1`.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{resolve_base, FieldSet, Layout};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{
    AssetField, BooleanField, ChoiceField, ColorField, NumericField, StringField,
};
use crate::sbc::panels::registry::{EditorSpec, Tab};

inventory::submit! {
    EditorSpec {
        name: "devFieldsView",
        tab: Tab::Dev,
        order: 0,
        caption: "Fields",
        tooltip: "Every field control, at rest and under input",
        image: "LuaUI/images/scenedit/info.png",
        make: || Box::new(DevFieldsView::new()),
    }
}

pub(crate) struct DevFieldsView {
    fields: FieldSet,
}

impl DevFieldsView {
    pub(crate) fn new() -> Self {
        DevFieldsView {
            fields: FieldSet::new(vec![
                Box::new(
                    StringField::new("text", "String", "hello")
                        .with_tooltip("Single-line text. Enter commits, Escape reverts."),
                ),
                Box::new(
                    StringField::new("empty", "String (empty)", "")
                        .with_tooltip("The same control with no value."),
                ),
                Box::new(
                    NumericField::new("number", "Numeric", 42.0)
                        .with_tooltip("Click to type a value, or drag to change it."),
                ),
                Box::new(
                    NumericField::new("bounded", "Numeric 0-100", 50.0)
                        .min(0.0)
                        .max(100.0)
                        .decimals(0)
                        .with_tooltip("Bounded 0-100: a drag crosses the range in ~200px."),
                ),
                Box::new(
                    NumericField::new("precise", "Numeric (3 dp)", 0.125)
                        .min(-1.0)
                        .max(1.0)
                        .decimals(3)
                        .with_tooltip("Three decimals, bounded -1..1."),
                ),
                Box::new(
                    BooleanField::new("flag_on", "Boolean (on)", true)
                        .with_tooltip("A checkbox, on."),
                ),
                Box::new(
                    BooleanField::new("flag_off", "Boolean (off)", false)
                        .with_tooltip("A checkbox, off."),
                ),
                Box::new(
                    ChoiceField::new(
                        "choice",
                        "Choice",
                        vec!["First".into(), "Second".into(), "Third".into()],
                    )
                    .with_tooltip("A drop-down of fixed items."),
                ),
                Box::new(
                    ColorField::new("colour", "Colour")
                        .with_tooltip("Opens the colour picker modal."),
                ),
                // `bitmaps/` because it is one of the few roots the VFS actually
                // lists (LuaUI/ and the VFS root both come back empty). It is flat,
                // so the picker's *folder* navigation is shown by the file dialog
                // instead -- the same GridView code drives both.
                Box::new(
                    AssetField::new("asset", "Asset", "bitmaps/")
                        .extensions(&["png", "jpg"])
                        .with_tooltip("Opens the asset picker: browse folders, pick a file."),
                ),
                // A group renders its fields on one row, as the XYZ vectors do.
                Box::new(NumericField::new("vec_x", "X", 1.0)),
                Box::new(NumericField::new("vec_y", "Y", 2.0)),
                Box::new(NumericField::new("vec_z", "Z", 3.0)),
            ]),
        }
    }

    fn layout(&self) -> Vec<Layout<'static>> {
        vec![
            Layout::Section("Text"),
            Layout::Field("text"),
            Layout::Field("empty"),
            Layout::Section("Numeric"),
            Layout::Field("number"),
            Layout::Field("bounded"),
            Layout::Field("precise"),
            Layout::Section("Boolean"),
            Layout::Field("flag_on"),
            Layout::Field("flag_off"),
            Layout::Section("Choice"),
            Layout::Field("choice"),
            Layout::Section("Pickers"),
            Layout::Field("colour"),
            Layout::Field("asset"),
            Layout::Section("Group (one row)"),
            Layout::Group(&["vec_x", "vec_y", "vec_z"]),
        ]
    }
}

impl Editor for DevFieldsView {
    fn generate_rml(&self) -> String {
        self.fields.generate_rml(&self.layout())
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

    /// The point of the gallery: say what each control produced.
    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
        _next: &mut u64,
    ) -> Vec<String> {
        let base = resolve_base(name);
        self.fields.read(base, interface);
        log::info!("dev-fields: {base} = {}", describe(self.fields.value(base)));
        vec![]
    }

    /// A drag changes the value without the DOM ever firing `change`, so the
    /// value is reported here or it is never reported at all.
    fn process_drag_end(&mut self, name: &str, _next: &mut u64) -> Vec<String> {
        let base = resolve_base(name);
        log::info!(
            "dev-fields: {base} = {} (dragged)",
            describe(self.fields.value(base))
        );
        vec![]
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, _models: &mut Models) {}

    crate::sb_field_editor_methods!();
}

fn describe(value: FieldValue) -> String {
    match value {
        FieldValue::Text(text) => format!("{text:?}"),
        FieldValue::Number(number) => number.to_string(),
        FieldValue::Bool(flag) => flag.to_string(),
        FieldValue::Color(rgba) => format!("{rgba:?}"),
    }
}
