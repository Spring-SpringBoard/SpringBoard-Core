use std::cell::RefCell;
use std::rc::Rc;

use super::super::graphics::Texture;

/// An editable FBO mirror of a map tile or shading texture, shared between the
/// manager, the active stroke, and the undo stacks.
pub(crate) struct TextureObj {
    pub texture: Texture,
    pub dirty: bool,
    /// Splat-normal / detail textures need mipmaps regenerated after a write.
    pub needs_mipmap: bool,
}

pub(crate) type Surface = Rc<RefCell<TextureObj>>;

/// A surface's contents copied off before a stroke overwrote it.
pub(crate) struct Backup {
    pub original: Surface,
    pub texture: Texture,
    pub dirty: bool,
}

pub(crate) fn new_surface(texture: Texture, needs_mipmap: bool) -> Surface {
    Rc::new(RefCell::new(TextureObj {
        texture,
        dirty: false,
        needs_mipmap,
    }))
}
