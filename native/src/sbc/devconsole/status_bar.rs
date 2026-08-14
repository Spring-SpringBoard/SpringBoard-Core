use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::devconsole::history_model::HistoryEntry;
use crate::sbc::devconsole::status_model::{StatusBarAction, StatusModel};
use crate::sbc::devconsole::view::StatusBarView;
use crate::sbc::objects::SelectionManager;

pub(super) struct StatusBar {
    model: StatusModel,
    view: Option<StatusBarView>,
}

impl StatusBar {
    pub(super) fn new(interface: &NativeInterfaceRef) -> Self {
        Self {
            model: StatusModel::new(interface),
            view: None,
        }
    }

    pub(super) fn ensure(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if self.view.is_none() {
            self.view = StatusBarView::new(interface)?;
        }
        Ok(())
    }

    pub(super) fn drain_actions(&self) -> Vec<StatusBarAction> {
        self.view
            .as_ref()
            .map_or_else(Vec::new, StatusBarView::drain_actions)
    }

    pub(super) fn render(
        &mut self,
        interface: &NativeInterfaceRef,
        selection: &SelectionManager,
        entries: &[HistoryEntry],
    ) -> Result<(), Error> {
        let Some(view) = &mut self.view else {
            return Ok(());
        };
        let status = self.model.refresh(interface, selection);
        view.render(
            interface,
            &status.position,
            status.performance,
            status.system_performance,
            status.version,
            entries,
        )
    }

    pub(super) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        if let Some(view) = self.view.take() {
            view.dispose(interface);
        }
    }
}
