use crate::sbc::command_system::model::{Model, ModelFactory};

inventory::submit! { ModelFactory { make: |_| Box::new(InputCounter::default()) } }

#[derive(Default)]
pub(crate) struct InputCounter {
    epoch: u64,
}

impl InputCounter {
    pub(crate) fn epoch(&self) -> u64 {
        self.epoch
    }

    pub(crate) fn bump(&mut self) {
        self.epoch = self.epoch.wrapping_add(1);
    }
}

impl Model for InputCounter {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
}
