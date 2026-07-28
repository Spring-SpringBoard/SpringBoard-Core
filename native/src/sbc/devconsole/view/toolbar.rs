use spring_native::prelude::{Error, NativeInterfaceRef};

use super::{element_by_id, Action, DevConsoleView};

impl DevConsoleView {
    pub(super) fn build_toolbar(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(doc) = self.document else {
            return Ok(());
        };
        for action in Action::ALL {
            let Some(button) = element_by_id(interface, doc, action.id()) else {
                continue;
            };
            let queue = self.actions.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(action);
                })?;
        }
        Ok(())
    }
}
