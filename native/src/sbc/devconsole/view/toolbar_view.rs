use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlDataVariable,
};

use crate::sbc::devconsole::toolbar_actions::ToolbarAction;
use crate::sbc::rml::element_by_id;

#[derive(Debug, Clone, Copy, Default)]
pub(crate) struct ToggleState {
    pub problems_only: bool,
    pub popup_on_error: bool,
    pub visible: bool,
    pub cheating: bool,
    pub global_los: bool,
    pub god_mode: bool,
}

impl ToggleState {
    fn is_pressed(&self, action: &ToolbarAction) -> bool {
        match *action {
            ToolbarAction::FilterProblems => self.problems_only,
            ToolbarAction::TogglePopupOnError => self.popup_on_error,
            ToolbarAction::ToggleCheating => self.cheating,
            ToolbarAction::ToggleGlobalLos => self.global_los,
            ToolbarAction::ToggleGodMode => self.god_mode,
            ToolbarAction::ToggleVisibility => !self.visible,
            _ => false,
        }
    }
}

type ToolbarActionQueue = Rc<RefCell<Vec<ToolbarAction>>>;

pub(crate) struct ToolbarView {
    pressed: Vec<(ToolbarAction, RmlDataVariable<'static, bool>)>,
    actions: ToolbarActionQueue,
}

impl ToolbarView {
    pub(crate) fn new(data_model: &RmlDataModel<'static>) -> Result<Self, Error> {
        let mut pressed = Vec::new();
        for action in ToolbarAction::ALL {
            if let Some(binding) = action.pressed_binding() {
                pressed.push((action, data_model.bind(binding, false)?));
            }
        }
        Ok(ToolbarView {
            pressed,
            actions: Rc::new(RefCell::new(Vec::new())),
        })
    }

    pub(crate) fn attach(&mut self, interface: &NativeInterfaceRef, doc: u64) -> Result<(), Error> {
        for action in ToolbarAction::ALL {
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

    pub(crate) fn drain_actions(&self) -> Vec<ToolbarAction> {
        self.actions.borrow_mut().drain(..).collect()
    }

    pub(crate) fn render_toggles(&self, state: ToggleState) -> Result<(), Error> {
        for (action, pressed) in &self.pressed {
            pressed.set(state.is_pressed(action))?;
        }
        Ok(())
    }
}
