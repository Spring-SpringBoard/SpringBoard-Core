//! Turning a brush pattern image into the greyscale shape the terrain commands
//! sample.
//!
//! Lua renders the pattern into a 256x256 FBO and reads the pixels back
//! (`TerrainManager:generateShape`). Nothing here needs the GPU: the file is
//! decoded straight out of the VFS, which also works before the first frame.

use spring_native::prelude::NativeInterfaceRef;

/// Matches the 256x256 render target Lua generates shapes into.
const SHAPE_SIZE: usize = 256;

/// A decoded pattern: one alpha value per texel, row-major.
pub(crate) struct Shape {
    pub size: usize,
    pub res: Vec<f32>,
}

/// Decode `path` from the VFS and resample it to `SHAPE_SIZE` square.
///
/// The shape is the image's alpha, as in Lua. Images with no alpha channel
/// would otherwise be a flat square brush, so their luminance is used instead --
/// Lua's `:r256,256:` load path gives them alpha 1 and the same flat square.
pub(crate) fn load_shape(interface: &NativeInterfaceRef, path: &str) -> Option<Shape> {
    let bytes = interface.vfs().load_file(path, "").ok()?;
    let decoded = image::load_from_memory(&bytes).ok()?;
    let rgba = decoded.to_rgba8();
    let (width, height) = rgba.dimensions();
    if width == 0 || height == 0 {
        return None;
    }

    let opaque = rgba.pixels().all(|p| p.0[3] == u8::MAX);

    let mut res = vec![0.0f32; SHAPE_SIZE * SHAPE_SIZE];
    for y in 0..SHAPE_SIZE {
        // Nearest-neighbour resample; the patterns are smooth blobs and the
        // brush itself is filtered when it is applied.
        let sy = (y * height as usize / SHAPE_SIZE).min(height as usize - 1);
        for x in 0..SHAPE_SIZE {
            let sx = (x * width as usize / SHAPE_SIZE).min(width as usize - 1);
            let pixel = rgba.get_pixel(sx as u32, sy as u32).0;
            let value = if opaque {
                // Luminance, matching the commented-out Lua formula.
                (pixel[0] as f32 + pixel[1] as f32 + pixel[2] as f32) / 3.0
            } else {
                pixel[3] as f32
            };
            res[x + y * SHAPE_SIZE] = value / 255.0;
        }
    }
    Some(Shape {
        size: SHAPE_SIZE,
        res,
    })
}

/// The `greyscale` payload of `SetHeightmapBrushCommand`, which takes it at the
/// top level of the envelope rather than under `opts`.
///
/// `res` is a map keyed by index. It must cover every texel: the command rebuilds
/// a dense array from it and rejects a map whose keys have holes, so a
/// transparent texel has to be sent as a zero rather than left out.
pub(crate) fn brush_opts(
    name: &str,
    shape: &Shape,
) -> crate::sbc::heightmap::commands::set_heightmap_brush_command::SetHeightmapBrushCommandOpts {
    use crate::sbc::heightmap::commands::set_heightmap_brush_command::SetHeightmapBrushCommandOpts;
    let res: std::collections::HashMap<usize, f32> = shape
        .res
        .iter()
        .enumerate()
        .map(|(index, value)| (index, *value))
        .collect();
    SetHeightmapBrushCommandOpts {
        res,
        size_x: shape.size,
        size_z: shape.size,
        name: name.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The command rebuilds a dense array and rejects keys with holes, so a
    /// transparent texel has to be sent rather than dropped.
    #[test]
    fn upload_sends_every_texel_including_the_transparent_ones() {
        let shape = Shape {
            size: 2,
            res: vec![0.0, 0.5, 0.0, 1.0],
        };
        let opts = brush_opts("brush", &shape);
        assert_eq!(opts.res.len(), 4, "every texel is uploaded");
        assert_eq!(opts.res[&0], 0.0);
        assert_eq!(opts.res[&1], 0.5);
        assert_eq!(opts.res[&3], 1.0);
        assert_eq!(opts.size_x, 2);
        assert_eq!(opts.name, "brush");
    }
}
