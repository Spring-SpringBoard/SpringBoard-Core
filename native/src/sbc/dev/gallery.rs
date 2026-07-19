//! Every field control the panel has, in one place -- a kitchen sink.
//!
//! It exists to be looked at and driven: a screenshot of this editor is a
//! screenshot of the whole control set, and a scenario that walks it exercises
//! every field type without needing a real editor that happens to use one. Each
//! commit logs the value it produced, so what the DOM sent is readable in the
//! run's log.
//!
//! Only in the Dev tab, which is off unless `SBC_DEV_PANEL=1`.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::fields::{
    AssetField, BooleanField, ChoiceField, ColorField, NumericField, StringField,
};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::{
    Behavior, Event, Item, Outcome, Phase, Runtime, TableEntry, TableModel,
};

inventory::submit! {
    EditorSpec {
        name: "devFieldsView",
        tab: Tab::Dev,
        order: 0,
        caption: "Fields",
        tooltip: "Every field control, at rest and under input",
        image: "LuaUI/images/scenedit/info.png",
        make: || Box::new(Runtime::new(DevFieldsBehavior, dev_fields_model())),
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum DevField {
    Text,
    Empty,
    Number,
    Bounded,
    Precise,
    FlagOn,
    FlagOff,
    Choice,
    Colour,
    Asset,
    VecX,
    VecY,
    VecZ,
}

use DevField::*;

fn dev_fields_model() -> TableModel<DevField> {
    TableModel::new(vec![
        TableEntry::new(
            Text,
            Box::new(
                StringField::new("text", "String", "hello")
                    .with_tooltip("Single-line text. Enter commits, Escape reverts."),
            ),
        ),
        TableEntry::new(
            Empty,
            Box::new(
                StringField::new("empty", "String (empty)", "")
                    .with_tooltip("The same control with no value."),
            ),
        ),
        TableEntry::new(
            Number,
            Box::new(
                NumericField::new("number", "Numeric", 42.0)
                    .with_tooltip("Click to type a value, or drag to change it."),
            ),
        ),
        TableEntry::new(
            Bounded,
            Box::new(
                NumericField::new("bounded", "Numeric 0-100", 50.0)
                    .min(0.0)
                    .max(100.0)
                    .decimals(0)
                    .with_tooltip("Bounded 0-100: a drag crosses the range in ~200px."),
            ),
        ),
        TableEntry::new(
            Precise,
            Box::new(
                NumericField::new("precise", "Numeric (3 dp)", 0.125)
                    .min(-1.0)
                    .max(1.0)
                    .decimals(3)
                    .with_tooltip("Three decimals, bounded -1..1."),
            ),
        ),
        TableEntry::new(
            FlagOn,
            Box::new(
                BooleanField::new("flag_on", "Boolean (on)", true).with_tooltip("A checkbox, on."),
            ),
        ),
        TableEntry::new(
            FlagOff,
            Box::new(
                BooleanField::new("flag_off", "Boolean (off)", false)
                    .with_tooltip("A checkbox, off."),
            ),
        ),
        TableEntry::new(
            Choice,
            Box::new(
                ChoiceField::new(
                    "choice",
                    "Choice",
                    vec!["First".into(), "Second".into(), "Third".into()],
                )
                .with_tooltip("A drop-down of fixed items."),
            ),
        ),
        TableEntry::new(
            Colour,
            Box::new(
                ColorField::new("colour", "Colour").with_tooltip("Opens the colour picker modal."),
            ),
        ),
        // A root inside the default `core` asset pack. The picker opens
        // directly on that usable directory, not on a pack chooser.
        TableEntry::new(
            Asset,
            Box::new(
                AssetField::new("asset", "Asset", "brush_textures/")
                    .extensions(&["png", "jpg"])
                    .with_tooltip("Opens the asset picker: browse packs, pick a file."),
            ),
        ),
        // A row renders its fields side by side, as the XYZ vectors do.
        TableEntry::new(
            VecX,
            Box::new(NumericField::new("vec_x", "X", 1.0).compact()),
        ),
        TableEntry::new(
            VecY,
            Box::new(NumericField::new("vec_y", "Y", 2.0).compact()),
        ),
        TableEntry::new(
            VecZ,
            Box::new(NumericField::new("vec_z", "Z", 3.0).compact()),
        ),
    ])
}

struct DevFieldsBehavior;

impl Behavior for DevFieldsBehavior {
    type Model = TableModel<DevField>;

    fn layout(&self, _model: &Self::Model) -> Vec<Item<DevField>> {
        vec![
            Item::Section("Text"),
            Item::Field(Text),
            Item::Field(Empty),
            Item::Section("Numeric"),
            Item::Field(Number),
            Item::Field(Bounded),
            Item::Field(Precise),
            Item::Section("Boolean"),
            Item::Field(FlagOn),
            Item::Field(FlagOff),
            Item::Section("Choice"),
            Item::Field(Choice),
            Item::Section("Pickers"),
            Item::Field(Colour),
            Item::Field(Asset),
            Item::Section("Group (one row)"),
            Item::Row(&[VecX, VecY, VecZ]),
        ]
    }

    fn refresh(
        &mut self,
        _model: &mut Self::Model,
        _engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
    }

    /// The point of the gallery: say what each control produced. A drag changes
    /// the value without the DOM ever firing `change`, so the dragged value is
    /// reported from its commit phase or it is never reported at all.
    fn apply(
        &mut self,
        event: Event<DevField>,
        model: &mut Self::Model,
        _engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, phase) = event;
        let suffix = match phase {
            Phase::Preview => " (dragged)",
            Phase::Commit => "",
        };
        log::info!(
            "dev-fields: {} = {}{suffix}",
            model.field_name(id),
            describe(model.value(id))
        );
        Outcome::default()
    }
}

fn describe(value: FieldValue) -> String {
    match value {
        FieldValue::Text(text) => format!("{text:?}"),
        FieldValue::Number(number) => number.to_string(),
        FieldValue::Bool(flag) => flag.to_string(),
        FieldValue::Color(rgba) => format!("{rgba:?}"),
    }
}
