//! The renderer as the editor last heard from it. Replies arrive as `renderLab` messages
//! (relayed by `api_sb_render_lab.lua`) and are kept here for the panel to read.

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
    /// Bumped as a reply of each kind arrives, so a panel knows what to rebuild.
    capabilities_revision: u64,
    state_revision: u64,
}

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
