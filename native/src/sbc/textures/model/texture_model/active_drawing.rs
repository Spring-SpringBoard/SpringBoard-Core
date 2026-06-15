use std::rc::Rc;

use spring_native::prelude::NativeInterfaceRef;

use super::super::graphics;
use super::surface::{Backup, Surface};

/// Backups collected for the current (not-yet-closed) stroke.
pub(super) struct ActiveDrawing {
    interface: NativeInterfaceRef,
    entries: Vec<Backup>,
}

impl ActiveDrawing {
    pub(super) fn new(interface: NativeInterfaceRef) -> Self {
        ActiveDrawing {
            interface,
            entries: Vec::new(),
        }
    }

    /// Back `surface` up once per stroke (no-op if already backed up).
    pub(super) fn set_active(&mut self, surface: &Surface) {
        if self
            .entries
            .iter()
            .any(|e| Rc::ptr_eq(&e.original, surface))
        {
            return;
        }
        let (src, dirty) = {
            let obj = surface.borrow();
            (obj.texture.clone(), obj.dirty)
        };
        let Some(backup) = graphics::copy_texture(&self.interface, &src) else {
            return;
        };
        self.entries.push(Backup {
            original: surface.clone(),
            texture: backup,
            dirty,
        });
    }

    /// Close the stroke, handing its backups to the undo stack.
    pub(super) fn take(&mut self) -> Vec<Backup> {
        std::mem::take(&mut self.entries)
    }

    /// Drop the stroke's backups without keeping them.
    pub(super) fn discard(&mut self) {
        for entry in std::mem::take(&mut self.entries) {
            let _ = self.interface.gfx().delete_texture(&entry.texture);
        }
    }

    pub(super) fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}
