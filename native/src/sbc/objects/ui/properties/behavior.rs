use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::objects::{ObjectManager, SelectionManager};
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::runtime::{Behavior, EditorModel, Event, Item, Outcome, Watch};
use crate::sbc::teams::TeamManager;

use super::layout;
use super::model::{
    component, component_name, is_angle, number_f, sub_parts, Position, PropertiesModel,
    PropertyLayout, SelectedObject,
};

pub(crate) struct PropertiesBehavior;

impl Behavior for PropertiesBehavior {
    type Model = PropertiesModel;

    fn layout(&self, model: &PropertiesModel) -> Vec<Item<usize>> {
        layout::layout(model)
    }

    /// Whether the selection changed since the last look: cheap, runs each
    /// tick. The layout differs between "no selection" and "an object", so any
    /// change regenerates the markup.
    fn watch(&mut self, model: &mut PropertiesModel, models: &mut Models) -> Watch {
        if models.get::<SelectionManager>().revision() != model.selection_revision {
            Watch::Rebuild
        } else {
            Watch::Unchanged
        }
    }

    /// Follow the selection and read the primary object's fields. Position is
    /// the average over matching selected objects, as in Chili's `avgPos`.
    fn refresh(
        &mut self,
        model: &mut PropertiesModel,
        _engine: &NativeInterfaceRef,
        models: &mut Models,
    ) {
        model.selection_revision = models.get::<SelectionManager>().revision();
        let selected = models.get::<SelectionManager>().all();
        model.selected = selected.first().copied();
        model.selection.clear();
        model.average_position = None;

        let Some((kind, model_id)) = model.selected else {
            return;
        };
        model.teams = models
            .get::<TeamManager>()
            .all_teams()
            .iter()
            .map(|team| (team.id, format!("Team {}", team.id)))
            .collect();

        let teams = model.teams.clone();
        let objects = models.get::<ObjectManager>();
        model.selection = selected
            .into_iter()
            .map(|(kind, model_id)| SelectedObject {
                kind,
                model_id,
                position: objects
                    .field_json(kind, model_id, "pos")
                    .and_then(|value| Position::from_json(&value)),
            })
            .collect();
        model.average_position = Position::average(&model.selection, kind);
        // A sub-object's keys come from the object itself, so the fields are
        // rebuilt for a new object, not just for a new kind.
        if model.fields_for != Some((kind, model_id)) {
            if let Some(descriptors) = objects.field_descriptors(kind) {
                model.rebuild_fields(kind, model_id, descriptors, objects, &teams);
            }
        }

        let objects = models.get::<ObjectManager>();
        for row in model.layout.clone() {
            match row {
                PropertyLayout::Field(name) => {
                    if let Some(value) = objects.field_json(kind, model_id, &name) {
                        model.set_json_field(&name, &value);
                    }
                }
                PropertyLayout::Group(names) => {
                    if let Some((field, _)) = names.first().and_then(|name| component(name)) {
                        let value = if field == "pos" {
                            model.average_position.map(Position::json)
                        } else {
                            objects.field_json(kind, model_id, field)
                        };
                        if let Some(value) = value {
                            for axis in ["x", "y", "z"] {
                                let mut component = number_f(&value[axis]);
                                if is_angle(field) {
                                    component = component.to_degrees();
                                }
                                model.set(
                                    &component_name(field, axis),
                                    FieldValue::Number(component),
                                );
                            }
                        }
                        continue;
                    }
                    // A sub-object's row: read the parent once, then each key.
                    let Some((parent, _)) = names.first().and_then(|name| sub_parts(name)) else {
                        continue;
                    };
                    let Some(value) = objects.field_json(kind, model_id, parent) else {
                        continue;
                    };
                    for name in &names {
                        let Some((_, key)) = sub_parts(name) else {
                            continue;
                        };
                        model.set_sub_field(name, key, &value[key]);
                    }
                }
                PropertyLayout::Section(_) => {}
            }
        }
    }

    fn apply(
        &mut self,
        event: Event<usize>,
        model: &mut PropertiesModel,
        _engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, _phase) = event;
        Outcome::commands(model.commit(&model.name_of(id)))
    }
}
