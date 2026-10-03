use std::time::{Duration, Instant};

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome, Watch};

use super::layout;
use super::model::{LabModel, Role, NONE};
use super::protocol;
use super::renderer::RendererModel;

/// Interval between capability requests until the renderer answers.
const ASK_AGAIN: Duration = Duration::from_secs(2);

#[derive(Default)]
pub(crate) struct LabBehavior {
    asked_at: Option<Instant>,
    rebuild: bool,
}

impl Behavior for LabBehavior {
    type Model = LabModel;

    fn layout(&self, model: &LabModel) -> Vec<Item<usize>> {
        layout::layout(model)
    }

    fn refresh(&mut self, model: &mut LabModel, engine: &NativeInterfaceRef, models: &mut Models) {
        let renderer = models.get::<RendererModel>();
        match renderer.capabilities() {
            Some(capabilities) => {
                if model.built_from != renderer.capabilities_revision() {
                    model.build(capabilities, renderer.capabilities_revision());
                }
                if model.state_from != renderer.state_revision() {
                    let (state, revision) = (renderer.state().clone(), renderer.state_revision());
                    model.take_state(&state, revision);
                }
                model.show_display();
            }
            None => self.ask(engine),
        }
    }

    fn watch(&mut self, model: &mut LabModel, models: &mut Models) -> Watch {
        if std::mem::take(&mut self.rebuild) {
            return Watch::Rebuild;
        }
        let renderer = models.get::<RendererModel>();
        if renderer.capabilities().is_some() && model.built_from != renderer.capabilities_revision()
        {
            return Watch::Rebuild;
        }
        if model.state_from != renderer.state_revision() {
            // Values and the bound status line update in place.
            return Watch::Refresh;
        }
        Watch::Unchanged
    }

    fn tick(
        &mut self,
        model: &mut LabModel,
        engine: &NativeInterfaceRef,
        _document: u64,
    ) -> Outcome {
        if model.capabilities.is_none() {
            self.ask(engine);
        }
        Outcome::default()
    }

    fn apply(
        &mut self,
        event: Event<usize>,
        model: &mut LabModel,
        engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, _phase) = event;
        let Some(role) = model.role(id).cloned() else {
            return Outcome::default();
        };
        let value = model.value(id);
        match role {
            Role::Control(control) => {
                if model.control(&control).is_some_and(|spec| spec.is_button()) {
                    protocol::set(engine, &control, &FieldValue::Number(1.0));
                    return Outcome::default();
                }
                let value = if let (Some(spec), FieldValue::Text(name)) =
                    (model.control(&control), &value)
                {
                    if spec.kind == "choice" {
                        let Some(index) = spec.choices.iter().position(|item| item == name) else {
                            return Outcome::default();
                        };
                        FieldValue::Number(index as f32)
                    } else {
                        value
                    }
                } else {
                    value
                };
                protocol::set(engine, &control, &value);
            }
            Role::Overlay(overlay) => {
                protocol::overlay(engine, &overlay, matches!(value, FieldValue::Bool(true)));
            }
            Role::View => {
                if let FieldValue::Text(name) = value {
                    let view = model
                        .capabilities
                        .as_ref()
                        .and_then(|c| c.views.iter().find(|view| view.name == name));
                    if let Some(view) = view {
                        protocol::view(engine, &view.id);
                    }
                }
            }
            Role::Solo => {
                if let FieldValue::Text(name) = value {
                    let control = (name != NONE)
                        .then(|| model.control(&name))
                        .flatten()
                        .map(|control| control.id.clone());
                    protocol::solo(engine, control.as_deref());
                }
            }
            Role::Explain => {
                if let FieldValue::Text(name) = value {
                    model.explaining = Some(name);
                }
                self.rebuild = true;
            }
            Role::Scene => model.show_display(),
            Role::LoadScene => {
                let chosen = model
                    .id_of_role(&Role::Scene)
                    .map(|scene| model.value(scene));
                if let Some(FieldValue::Text(name)) = chosen {
                    let scene = model
                        .capabilities
                        .as_ref()
                        .and_then(|c| c.scenes.iter().find(|scene| scene.name == name));
                    if let Some(scene) = scene {
                        protocol::scene(engine, &scene.id);
                    }
                }
            }
            Role::Reset => protocol::reset(engine, model.reset_scope()),
        }
        Outcome::default()
    }
}

impl LabBehavior {
    fn ask(&mut self, engine: &NativeInterfaceRef) {
        if self.asked_at.is_some_and(|at| at.elapsed() < ASK_AGAIN) {
            return;
        }
        self.asked_at = Some(Instant::now());
        protocol::list(engine);
    }
}
