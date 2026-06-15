use std::rc::Rc;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::CommandId;
use crate::sbc::command_system::history::HistoryEvent;

use super::super::graphics::{self, Texture};
use super::surface::Backup;

struct Stroke {
    cmd_id: Option<CommandId>,
    entries: Vec<Backup>,
}

pub(super) struct TextureUndoStack {
    interface: NativeInterfaceRef,
    undo: Vec<Stroke>,
    redo: Vec<Stroke>,
}

impl TextureUndoStack {
    pub(super) fn new(interface: NativeInterfaceRef) -> Self {
        TextureUndoStack {
            interface,
            undo: Vec::new(),
            redo: Vec::new(),
        }
    }

    /// Close a stroke's backups onto the undo stack, dropping any pending redo.
    pub(super) fn push(&mut self, cmd_id: Option<CommandId>, entries: Vec<Backup>) {
        if entries.is_empty() {
            return;
        }
        self.undo.push(Stroke { cmd_id, entries });
        self.clear_stack(StackKind::Redo);
    }

    /// Revert the last (or matching) stroke, staging its inverse for redo.
    pub(super) fn undo(&mut self, cmd_id: Option<CommandId>) {
        let Some(stroke) = Self::take(&mut self.undo, cmd_id) else {
            return;
        };
        let inverse = self.restore(stroke.entries);
        if !inverse.is_empty() {
            self.redo.push(Stroke {
                cmd_id: stroke.cmd_id,
                entries: inverse,
            });
        }
    }

    /// Re-apply the last (or matching) undone stroke.
    pub(super) fn redo(&mut self, cmd_id: Option<CommandId>) {
        let Some(stroke) = Self::take(&mut self.redo, cmd_id) else {
            return;
        };
        let inverse = self.restore(stroke.entries);
        if !inverse.is_empty() {
            self.undo.push(Stroke {
                cmd_id: stroke.cmd_id,
                entries: inverse,
            });
        }
    }

    /// React to command-history changes (drop / merge / clear).
    pub(super) fn on_history_events(&mut self, events: &[HistoryEvent]) {
        for event in events {
            match event {
                HistoryEvent::Dropped { cmd_id } | HistoryEvent::UndoEvicted { cmd_id } => {
                    self.drop_by_id(&[*cmd_id]);
                }
                HistoryEvent::RedoCleared { cmd_ids } => self.drop_by_id(cmd_ids),
                HistoryEvent::Merged {
                    cmd_id,
                    source_cmd_ids,
                } => self.merge(*cmd_id, source_cmd_ids),
                HistoryEvent::Cleared { .. } => self.clear(),
            }
        }
    }

    pub(super) fn clear(&mut self) {
        self.clear_stack(StackKind::Undo);
        self.clear_stack(StackKind::Redo);
    }

    pub(super) fn undo_depth(&self) -> usize {
        self.undo.len()
    }

    pub(super) fn redo_depth(&self) -> usize {
        self.redo.len()
    }

    // --- internals ---

    /// Blit each backup onto its surface, returning the pre-restore contents as
    /// the inverse stroke for the opposite stack.
    fn restore(&self, entries: Vec<Backup>) -> Vec<Backup> {
        let mut inverse = Vec::with_capacity(entries.len());
        // After a merge a surface can appear twice; restore only its newest.
        let mut seen: Vec<*const ()> = Vec::new();
        for entry in entries {
            let key = Rc::as_ptr(&entry.original) as *const ();
            if seen.contains(&key) {
                self.delete(&entry.texture);
                continue;
            }
            seen.push(key);

            let (live, cur_dirty, needs_mipmap) = {
                let obj = entry.original.borrow();
                (obj.texture.clone(), obj.dirty, obj.needs_mipmap)
            };
            if let Some(snapshot) = graphics::copy_texture(&self.interface, &live) {
                inverse.push(Backup {
                    original: entry.original.clone(),
                    texture: snapshot,
                    dirty: cur_dirty,
                });
            }
            graphics::blit(&self.interface, &entry.texture, &live);
            if needs_mipmap {
                graphics::generate_mipmap(&self.interface, &live);
            }
            entry.original.borrow_mut().dirty = entry.dirty;
            self.delete(&entry.texture);
        }
        inverse
    }

    /// The stroke for `cmd_id`, or the most recent if `None`.
    fn take(stack: &mut Vec<Stroke>, cmd_id: Option<CommandId>) -> Option<Stroke> {
        if let Some(cmd_id) = cmd_id {
            let pos = stack
                .iter()
                .rposition(|stroke| stroke.cmd_id == Some(cmd_id))?;
            Some(stack.remove(pos))
        } else {
            stack.pop()
        }
    }

    fn clear_stack(&mut self, kind: StackKind) {
        let stack = match kind {
            StackKind::Undo => std::mem::take(&mut self.undo),
            StackKind::Redo => std::mem::take(&mut self.redo),
        };
        for stroke in stack {
            for entry in stroke.entries {
                self.delete(&entry.texture);
            }
        }
    }

    fn drop_by_id(&mut self, cmd_ids: &[CommandId]) {
        if cmd_ids.is_empty() {
            return;
        }
        let dropped = Self::drain(&mut self.undo, cmd_ids)
            .into_iter()
            .chain(Self::drain(&mut self.redo, cmd_ids));
        for stroke in dropped.collect::<Vec<_>>() {
            for entry in stroke.entries {
                self.delete(&entry.texture);
            }
        }
    }

    fn drain(stack: &mut Vec<Stroke>, cmd_ids: &[CommandId]) -> Vec<Stroke> {
        let mut removed = Vec::new();
        let mut i = 0;
        while i < stack.len() {
            if stack[i].cmd_id.is_some_and(|id| cmd_ids.contains(&id)) {
                removed.push(stack.remove(i));
            } else {
                i += 1;
            }
        }
        removed
    }

    fn merge(&mut self, cmd_id: CommandId, source_cmd_ids: &[CommandId]) {
        if source_cmd_ids.is_empty() {
            return;
        }
        Self::merge_stack(&mut self.undo, cmd_id, source_cmd_ids);
        Self::merge_stack(&mut self.redo, cmd_id, source_cmd_ids);
    }

    fn merge_stack(stack: &mut Vec<Stroke>, cmd_id: CommandId, source_cmd_ids: &[CommandId]) {
        let mut merged = Vec::new();
        let mut insert_at = None;
        let mut i = 0;
        while i < stack.len() {
            if stack[i]
                .cmd_id
                .is_some_and(|id| source_cmd_ids.contains(&id))
            {
                let stroke = stack.remove(i);
                insert_at.get_or_insert(i);
                merged.extend(stroke.entries);
            } else {
                i += 1;
            }
        }
        if merged.is_empty() {
            return;
        }
        if let Some(stroke) = stack.iter_mut().find(|s| s.cmd_id == Some(cmd_id)) {
            stroke.entries.extend(merged);
        } else {
            stack.insert(
                insert_at.unwrap_or(stack.len()),
                Stroke {
                    cmd_id: Some(cmd_id),
                    entries: merged,
                },
            );
        }
    }

    fn delete(&self, texture: &Texture) {
        let _ = self.interface.gfx().delete_texture(texture);
    }
}

enum StackKind {
    Undo,
    Redo,
}
