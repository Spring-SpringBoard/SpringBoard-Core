use std::any::Any;

use crate::sbc::command_system::model::{Model, ModelFactory};

#[derive(Default)]
pub(crate) struct UiLayout {
    pub(crate) sidebar_minimized: bool,
    pub(crate) status_bar_minimized: bool,
}

inventory::submit! {
    ModelFactory { make: |_| Box::new(UiLayout::default()) }
}

impl Model for UiLayout {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl UiLayout {
    pub(crate) fn toggle_sidebar(&mut self) {
        self.sidebar_minimized = !self.sidebar_minimized;
    }

    pub(crate) fn toggle_status_bar(&mut self) {
        self.status_bar_minimized = !self.status_bar_minimized;
    }
}
