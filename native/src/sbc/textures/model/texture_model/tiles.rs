use spring_native::prelude::NativeInterfaceRef;

use super::super::graphics::{self, Texture};
use super::surface::{new_surface, Surface};

const DEFAULT_TEXTURE_SIZE: i32 = 1024;

/// A diffuse tile in a paint region, with the region origin's tile-space offset.
pub(crate) struct RegionTile {
    pub i: i32,
    pub j: i32,
    pub texture: Texture,
    /// Region origin minus the tile index, in tile units.
    pub offset_x: f32,
    pub offset_z: f32,
}

/// The editable diffuse tiles mirroring the map's square textures.
pub(crate) struct TileStore {
    interface: NativeInterfaceRef,
    tiles: Vec<((i32, i32), Surface)>,
    texture_size: i32,
    tiles_x: i32,
    tiles_z: i32,
    generated: bool,
}

impl TileStore {
    pub(super) fn new(interface: NativeInterfaceRef) -> Self {
        TileStore {
            interface,
            tiles: Vec::new(),
            texture_size: DEFAULT_TEXTURE_SIZE,
            tiles_x: 0,
            tiles_z: 0,
            generated: false,
        }
    }

    pub(crate) fn texture_size(&self) -> i32 {
        self.texture_size
    }

    /// Create the editable tiles from the map's square textures (idempotent).
    /// Returns whether tiles now exist (false only on failure).
    pub(crate) fn generate(&mut self) -> bool {
        if self.generated {
            return true;
        }
        let (texture_size, num_squares_x, num_squares_z) =
            match self.interface.vfs().get_map_square_texture_info() {
                Ok((size, x, z)) if size > 0 && x > 0 && z > 0 => (size, x, z),
                other => {
                    log::error!("texture_model: could not read map square info: {other:?}");
                    return false;
                }
            };
        self.texture_size = texture_size;
        self.tiles_x = num_squares_x - 1;
        self.tiles_z = num_squares_z - 1;

        let vfs = self.interface.vfs();
        let Some(scratch) = graphics::create_fbo_texture(&self.interface, texture_size, texture_size)
        else {
            log::error!("texture_model: failed to create scratch texture");
            return false;
        };

        for i in 0..num_squares_x {
            for j in 0..num_squares_z {
                let Some(tile) =
                    graphics::create_fbo_texture(&self.interface, texture_size, texture_size)
                else {
                    continue;
                };
                match vfs.get_map_square_texture(i, j, 0, &scratch, 0) {
                    Ok(true) => {}
                    other => {
                        log::error!("texture_model: get_map_square_texture({i}, {j}) failed: {other:?}");
                        let _ = self.interface.gfx().delete_texture(&tile);
                        continue;
                    }
                }
                graphics::blit(&self.interface, &scratch, &tile);
                match vfs.set_map_square_texture(i, j, &tile) {
                    Ok(true) => {}
                    other => {
                        log::error!("texture_model: set_map_square_texture({i}, {j}) failed: {other:?}");
                        let _ = self.interface.gfx().delete_texture(&tile);
                        continue;
                    }
                }
                self.tiles.push(((i, j), new_surface(tile, false)));
            }
        }
        let _ = self.interface.gfx().delete_texture(&scratch);
        self.generated = true;
        true
    }

    pub(crate) fn texture(&self, i: i32, j: i32) -> Option<Texture> {
        self.surface(i, j).map(|s| s.borrow().texture.clone())
    }

    pub(crate) fn dirty(&self, i: i32, j: i32) -> bool {
        self.surface(i, j).map(|s| s.borrow().dirty).unwrap_or(false)
    }

    pub(crate) fn mark_dirty(&mut self, i: i32, j: i32) {
        if let Some(surface) = self.surface(i, j) {
            surface.borrow_mut().dirty = true;
        }
    }

    pub(super) fn region_bounds(&self, start_x: f32, start_z: f32, end_x: f32, end_z: f32) -> (i32, i32, i32, i32) {
        let i1 = start_x.floor().max(0.0) as i32;
        let i2 = (end_x.floor() as i32).min(self.tiles_x);
        let j1 = start_z.floor().max(0.0) as i32;
        let j2 = (end_z.floor() as i32).min(self.tiles_z);
        (i1, i2, j1, j2)
    }

    pub(super) fn surface(&self, i: i32, j: i32) -> Option<&Surface> {
        self.tiles
            .iter()
            .find(|((ti, tj), _)| *ti == i && *tj == j)
            .map(|(_, s)| s)
    }
}
