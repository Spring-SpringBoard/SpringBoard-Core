//! Keeps the panel's fields and the shared brush in step. A state bumps the
//! brush's revision when the wheel resizes it or a right-click picks a height,
//! and then the fields follow; otherwise the fields lead.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::states::BrushSettings;

#[derive(Default)]
pub(crate) struct BrushSync {
    /// The brush revision the fields last showed; a bump means a state changed
    /// the brush and the fields should follow.
    revision: u64,
}

impl BrushSync {
    pub(crate) fn sync(
        &mut self,
        editor: &mut (dyn Editor + '_),
        models: &mut Models,
        interface: &NativeInterfaceRef,
    ) {
        let brush = models.get::<BrushSettings>();
        if brush.revision != self.revision {
            self.revision = brush.revision;
            let brush = brush.clone();
            editor.read_brush(&brush, interface);
            return;
        }
        editor.write_brush(brush);
    }
}
