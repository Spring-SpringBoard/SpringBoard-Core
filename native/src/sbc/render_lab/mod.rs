mod behavior;
mod catalogue;
mod layout;
mod model;
mod panel;
mod parts;
mod protocol;
mod renderer;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;

use renderer::RendererModel;

/// Whether the running game's renderer offers any of the Effects tab's editors.
pub(crate) fn offers_effects(models: &mut Models) -> bool {
    models
        .get::<RendererModel>()
        .capabilities()
        .is_some_and(|capabilities| {
            panel::EFFECTS_PANELS
                .iter()
                .any(|panel| capabilities.offers(panel))
        })
}

/// One part of a renderer reply sent in parts (what follows `springboard|lab-part|`): the
/// reply's JSON once its last part is in.
pub(crate) fn take_reply_part(models: &mut Models, part: &str) -> Option<String> {
    models.get::<RendererModel>().parts.take(part)
}

/// Ask the renderer what it offers until it answers, without a Lab open: the tab bar needs to
/// know whether to show the Effects tab.
pub(crate) fn ask_until_answered(engine: &NativeInterfaceRef, models: &mut Models) {
    if models.get::<RendererModel>().due_to_ask() {
        protocol::list(engine);
    }
}
