//! The field commit protocol: which field is being edited, which commit is an
//! echo of our own write, and what value a drag started from. One owner for the
//! rules that keep an interaction to exactly one undoable command.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::{Command, PreviewCommand};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::FieldValue;

#[derive(Default)]
pub(crate) struct FieldSession {
    /// The field currently in text-edit mode. Owning this here is what keeps a
    /// commit to exactly one command: the DOM would otherwise fire "change" on
    /// every keystroke.
    editing: Option<String>,
    /// The last field committed by Enter or a select change; the `blur` it
    /// triggers is swallowed.
    just_committed: Option<String>,
    /// The value a numeric drag started from, so the committed command captures
    /// it as the state undo returns to.
    drag_original: Option<(String, FieldValue)>,
}

impl FieldSession {
    pub(crate) fn reset(&mut self) {
        self.editing = None;
        self.just_committed = None;
        self.drag_original = None;
    }

    pub(crate) fn editing(&self) -> Option<&str> {
        self.editing.as_deref()
    }

    pub(crate) fn begin_edit(&mut self, field: String) {
        self.editing = Some(field);
    }

    /// Escape while editing: leave edit mode without committing.
    pub(crate) fn cancel_edit(&mut self) -> Option<String> {
        self.editing.take()
    }

    /// Remember what a drag began from, so undo returns to it.
    pub(crate) fn begin_drag(&mut self, field: String, editor: &dyn Editor) {
        self.drag_original = Some((field.clone(), editor.field_value(&field)));
    }

    /// Escape in a field: the edit is discarded, so the value the editor holds
    /// goes back on screen. The blur that follows is suppressed the same way an
    /// Enter's is -- otherwise it would commit the text still sitting in the box.
    pub(crate) fn revert_field(
        &mut self,
        name: &str,
        editor: Option<&mut (dyn Editor + '_)>,
        interface: &NativeInterfaceRef,
    ) {
        if self.editing.as_deref() == Some(name) {
            self.editing = None;
        }
        self.just_committed = Some(name.to_string());
        if let Some(ed) = editor {
            if let Err(err) = ed.write_field_values(interface) {
                log::warn!("reverting {name}: {err:?}");
            }
        }
    }

    /// Commit a field once, *if the value actually changed*.
    ///
    /// The fields are a projection of the model: the editor writes the model's
    /// values into the DOM, and RmlUi answers by firing `change` for each one it
    /// was handed. Those events carry the value we just wrote, so an edit is
    /// only an edit when the value that comes back differs from the one that
    /// went out. Anything else is our own write echoing, and emits nothing.
    ///
    /// This is why there is no "am I currently writing?" flag: the question is
    /// not *when* the event arrived, it is *whether it changed anything*.
    pub(crate) fn commit_field(
        &mut self,
        name: &str,
        from_blur: bool,
        editor: Option<&mut (dyn Editor + '_)>,
        interface: &NativeInterfaceRef,
    ) -> Vec<Box<dyn Command>> {
        if self.editing.as_deref() == Some(name) {
            self.editing = None;
        }
        if from_blur && self.just_committed.as_deref() == Some(name) {
            self.just_committed = None;
            return vec![];
        }
        self.just_committed = (!from_blur).then(|| name.to_string());

        let Some(ed) = editor else {
            return vec![];
        };
        let before = ed.field_value(name);
        let commands = ed.process_change(name, interface);
        if ed.field_value(name) == before {
            return vec![];
        }
        commands
    }

    /// End a drag with exactly one undoable command.
    ///
    /// The previews already moved the engine off the value the drag began from,
    /// and the committed command captures whatever it finds as the state undo
    /// restores -- so put the original back (off-history) before committing.
    pub(crate) fn commit_drag(
        &mut self,
        field: &str,
        editor: Option<&mut (dyn Editor + '_)>,
        interface: &NativeInterfaceRef,
    ) -> Vec<Box<dyn Command>> {
        let original = self
            .drag_original
            .take()
            .filter(|(name, _)| name == field)
            .map(|(_, value)| value);

        let Some(editor) = editor else {
            return vec![];
        };
        let current = editor.field_value(field);
        let mut commands = Vec::new();
        if let Some(original) = original {
            commands.extend(self.apply_field_value(field, original, true, editor, interface));
        }
        commands.extend(self.apply_field_value(field, current, false, editor, interface));
        commands
    }

    /// Push a value into the field and produce its command, either as an
    /// off-history preview or as a committed, undoable change.
    pub(crate) fn apply_field_value(
        &mut self,
        field: &str,
        value: FieldValue,
        preview: bool,
        editor: &mut (dyn Editor + '_),
        interface: &NativeInterfaceRef,
    ) -> Vec<Box<dyn Command>> {
        editor.set_field_value(field, value, interface);
        let commands = editor.process_drag_end(field, preview);
        if preview {
            as_previews(commands)
        } else {
            commands
        }
    }

    /// The field's current value as an off-history preview (a drag step moved it).
    pub(crate) fn preview_field(
        &mut self,
        field: &str,
        editor: &mut (dyn Editor + '_),
    ) -> Vec<Box<dyn Command>> {
        as_previews(editor.process_drag_end(field, true))
    }
}

/// Wrap commands as off-history previews (apply to the engine, stay out of the
/// undo stack). The typed counterpart of the old `as_preview` envelope re-write.
fn as_previews(commands: Vec<Box<dyn Command>>) -> Vec<Box<dyn Command>> {
    commands
        .into_iter()
        .map(|c| Box::new(PreviewCommand { inner: c }) as Box<dyn Command>)
        .collect()
}
