use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::CommandId;
use crate::sbc::command_system::history::HistoryEvent;

use super::active_drawing::ActiveDrawing;
use super::surface::Surface;
use super::tiles::{RegionTile, TileStore};
use super::undo_stack::TextureUndoStack;

/// The texture undo system: the in-progress stroke plus the undo/redo stacks.
pub(crate) struct TextureHistory {
    active: ActiveDrawing,
    undo: TextureUndoStack,
}

impl TextureHistory {
    pub(super) fn new(interface: NativeInterfaceRef) -> Self {
        TextureHistory {
            active: ActiveDrawing::new(interface),
            undo: TextureUndoStack::new(interface),
        }
    }

    /// Back a surface up into the current stroke (once per stroke).
    pub(crate) fn backup(&mut self, surface: &Surface) {
        self.active.set_active(surface);
    }

    /// Back up every tile overlapping the region and return them for painting.
    pub(crate) fn back_up_region(
        &mut self,
        tiles: &TileStore,
        start_x: f32,
        start_z: f32,
        end_x: f32,
        end_z: f32,
    ) -> Vec<RegionTile> {
        let (i1, i2, j1, j2) = tiles.region_bounds(start_x, start_z, end_x, end_z);
        let mut out = Vec::new();
        for i in i1..=i2 {
            for j in j1..=j2 {
                let Some(surface) = tiles.surface(i, j).cloned() else {
                    continue;
                };
                self.active.set_active(&surface);
                out.push(RegionTile {
                    i,
                    j,
                    texture: surface.borrow().texture.clone(),
                    offset_x: start_x - i as f32,
                    offset_z: start_z - j as f32,
                });
            }
        }
        out
    }

    /// Close the current stroke into one undo group.
    pub(crate) fn push_stack(&mut self, cmd_id: Option<CommandId>) {
        let entries = self.active.take();
        self.undo.push(cmd_id, entries);
    }

    /// Undo: revert the last (or matching) stroke, staging it for redo.
    pub(crate) fn pop_stack(&mut self, cmd_id: Option<CommandId>) {
        self.active.discard();
        self.undo.undo(cmd_id);
    }

    /// Close a fresh stroke, or replay an undone one during redo.
    pub(crate) fn close_or_redo_stroke(&mut self, cmd_id: Option<CommandId>) {
        if self.active.is_empty() {
            self.undo.redo(cmd_id);
        } else {
            self.push_stack(cmd_id);
        }
    }

    pub(crate) fn redo_stroke(&mut self, cmd_id: Option<CommandId>) {
        self.undo.redo(cmd_id);
    }

    pub(crate) fn clear(&mut self) {
        self.active.discard();
        self.undo.clear();
    }

    pub(crate) fn undo_depth(&self) -> usize {
        self.undo.undo_depth()
    }

    pub(crate) fn redo_depth(&self) -> usize {
        self.undo.redo_depth()
    }

    pub(crate) fn on_history_events(&mut self, events: &[HistoryEvent]) {
        if events
            .iter()
            .any(|e| matches!(e, HistoryEvent::Cleared { .. }))
        {
            self.active.discard();
        }
        self.undo.on_history_events(events);
    }
}
