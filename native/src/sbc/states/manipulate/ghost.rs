use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::panels::ModelShader;
use crate::sbc::states::highlight::{draw_object_ghost, ObjectGhost};

/// Draw the provisional object poses used by drag and rotate states.
pub(super) fn draw_ghosts(
    interface: &NativeInterfaceRef,
    shader: &mut ModelShader,
    ghosts: &[ObjectGhost],
) {
    for ghost in ghosts {
        draw_object_ghost(interface, shader, ghost);
    }
}
