//! Last renderer reply. Arrives as a `springboard|lab|` LuaRules message, dispatched to the
//! `renderLab` handler.

use std::time::{Duration, Instant};

use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::message_handler::MessageHandler;
use crate::sbc::sbc::SBC;

use super::catalogue::{Capabilities, State};

inventory::submit! { ModelFactory { make: |_iface| Box::new(RendererModel::default()) } }
inventory::submit! { MessageHandler { tag: "renderLab", handler: receive } }

#[derive(Default)]
pub(crate) struct RendererModel {
    capabilities: Option<Capabilities>,
    state: State,
    /// Incremented per reply kind; the panel rebuilds on change.
    capabilities_revision: u64,
    state_revision: u64,
    /// Unanswered capability requests sent by `due_to_ask`, and when the last went.
    asked: u32,
    asked_at: Option<Instant>,
}

/// Interval between unanswered capability requests: short while the game may still be
/// loading, long once it has stayed silent (a game without a renderer lab never answers).
const ASK_SOON: Duration = Duration::from_secs(3);
const ASK_LATER: Duration = Duration::from_secs(30);
const SOON_ASKS: u32 = 40;

impl Model for RendererModel {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
}

impl RendererModel {
    pub fn capabilities(&self) -> Option<&Capabilities> {
        self.capabilities.as_ref()
    }

    pub fn state(&self) -> &State {
        &self.state
    }

    pub fn capabilities_revision(&self) -> u64 {
        self.capabilities_revision
    }

    pub fn state_revision(&self) -> u64 {
        self.state_revision
    }

    /// Whether to send another capability request now; counts it if so.
    pub fn due_to_ask(&mut self) -> bool {
        if self.capabilities.is_some() {
            return false;
        }
        let wait = if self.asked < SOON_ASKS {
            ASK_SOON
        } else {
            ASK_LATER
        };
        if self.asked_at.is_some_and(|at| at.elapsed() < wait) {
            return false;
        }
        self.asked += 1;
        self.asked_at = Some(Instant::now());
        true
    }

    fn receive(&mut self, data: serde_json::Value) {
        let kind = data
            .get("kind")
            .and_then(|kind| kind.as_str())
            .unwrap_or("");
        match kind {
            "capabilities" => match serde_json::from_value::<Capabilities>(data.clone()) {
                Ok(capabilities) => {
                    self.capabilities = Some(capabilities);
                    self.capabilities_revision += 1;
                    self.take_state(data);
                }
                Err(err) => log::error!("renderLab capabilities: {err}"),
            },
            "values" => self.take_state(data),
            other => log::warn!("renderLab: unknown reply kind {other:?}"),
        }
    }

    fn take_state(&mut self, data: serde_json::Value) {
        match serde_json::from_value::<State>(data) {
            Ok(state) => {
                self.state = state;
                self.state_revision += 1;
            }
            Err(err) => log::error!("renderLab values: {err}"),
        }
    }
}

fn receive(sbc: &mut SBC, data: serde_json::Value) {
    sbc.model::<RendererModel>().receive(data);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sbc::command_system::model::Models;
    use crate::sbc::panels::registry::Tab;

    fn answered(categories: serde_json::Value) -> Models {
        let mut renderer = RendererModel::default();
        renderer.receive(serde_json::json!({
            "kind": "capabilities",
            "controls": [],
            "categories": categories,
        }));
        let mut models = Models::default();
        models.insert(renderer);
        models
    }

    #[test]
    fn the_effects_tab_shows_only_while_the_renderer_offers_its_editors() {
        let mut silent = Models::default();
        silent.insert(RendererModel::default());
        assert!(!Tab::visible(&mut silent).contains(&Tab::Effects));
        assert!(Tab::visible(&mut silent).contains(&Tab::Env));

        let mut render_only = answered(serde_json::json!([{"id":"material", "name":"Material"}]));
        assert!(!Tab::visible(&mut render_only).contains(&Tab::Effects));

        let mut effects = answered(serde_json::json!([
            {"id":"material", "name":"Material"},
            {"id":"scales", "name":"Effect scales", "panels":["tuning"]}
        ]));
        assert_eq!(
            Tab::visible(&mut effects),
            vec![Tab::Objects, Tab::Map, Tab::Env, Tab::Effects, Tab::Misc]
                .into_iter()
                .chain(Tab::all().into_iter().filter(|tab| *tab == Tab::Dev))
                .collect::<Vec<_>>()
        );
    }

    #[test]
    fn a_reply_with_values_refreshes_the_fields_in_place_and_new_controls_rebuild_them() {
        use crate::sbc::panels::runtime::{Behavior, Watch};
        use crate::sbc::render_lab::behavior::LabBehavior;
        use crate::sbc::render_lab::model::LabModel;

        let capabilities = serde_json::json!({
            "kind": "capabilities",
            "controls": [{"id":"fx.particles", "name":"Particles", "category":"runtime",
                "kind":"number", "value":0, "min":0, "max":1000000}],
            "categories": [{"id":"runtime", "name":"GPU particles", "panels":["runtime"]}],
        });
        let mut renderer = RendererModel::default();
        renderer.receive(capabilities.clone());
        let mut models = Models::default();
        models.insert(renderer);
        let mut behavior = LabBehavior::default();
        let mut model = LabModel::for_panel("runtime");
        assert_eq!(behavior.watch(&mut model, &mut models), Watch::Rebuild);
        let built = models
            .get::<RendererModel>()
            .capabilities()
            .cloned()
            .unwrap();
        model.build(&built, 1);
        model.take_state(&models.get::<RendererModel>().state().clone(), 1);
        assert_eq!(behavior.watch(&mut model, &mut models), Watch::Unchanged);

        // Readouts arrive many times a second: they must not rebuild the panel's markup.
        for count in 1..=5 {
            models.get::<RendererModel>().receive(serde_json::json!({
                "kind": "values", "values": {"fx.particles": count * 100},
                "lights": {"candidates": count, "chosen": count},
            }));
            assert_eq!(behavior.watch(&mut model, &mut models), Watch::Refresh);
            let state = models.get::<RendererModel>().state().clone();
            let revision = models.get::<RendererModel>().state_revision();
            model.take_state(&state, revision);
            assert!(model.status().starts_with(&format!("{count} lights")));
        }

        models.get::<RendererModel>().receive(capabilities);
        assert_eq!(behavior.watch(&mut model, &mut models), Watch::Rebuild);
    }

    #[test]
    fn asking_stops_once_answered_and_slows_when_nobody_answers() {
        let mut renderer = RendererModel::default();
        assert!(renderer.due_to_ask());
        assert!(!renderer.due_to_ask(), "not twice in a row");
        renderer.asked_at = Some(Instant::now() - ASK_SOON);
        assert!(renderer.due_to_ask());
        renderer.asked = SOON_ASKS;
        renderer.asked_at = Some(Instant::now() - ASK_SOON);
        assert!(!renderer.due_to_ask(), "a silent game is asked less often");
        renderer.receive(serde_json::json!({"kind":"capabilities", "controls":[]}));
        renderer.asked_at = None;
        assert!(!renderer.due_to_ask());
    }
}
