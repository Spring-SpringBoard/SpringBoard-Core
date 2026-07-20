//! Selects the field runtime currently receiving input.
//!
//! A modal form temporarily sits in front of the panel editor. Both implement
//! `Editor`, so the manager should not repeat that choice for every interaction.

use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_slot::EditorSlot;
use crate::sbc::panels::modal_stack::ModalStack;

pub(crate) struct ActiveFieldEditor<'a> {
    modals: &'a mut ModalStack,
    slot: &'a mut EditorSlot,
}

impl<'a> ActiveFieldEditor<'a> {
    pub(crate) fn new(modals: &'a mut ModalStack, slot: &'a mut EditorSlot) -> Self {
        Self { modals, slot }
    }

    pub(crate) fn get(&self) -> Option<&dyn Editor> {
        self.modals.field_editor().or_else(|| self.slot.editor())
    }

    pub(crate) fn get_mut(&mut self) -> Option<&mut (dyn Editor + '_)> {
        if self.modals.field_editor().is_some() {
            self.modals.field_editor_mut()
        } else {
            self.slot
                .editor_mut()
                .map(|editor| editor as &mut dyn Editor)
        }
    }
}
