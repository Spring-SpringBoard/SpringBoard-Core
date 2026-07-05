use crate::sbc::metal::ops::{export, read, write};
use crate::sbc::tests::tests_api::TestCtx;

fn metal_ops_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let original = read::read(ctx.sbc.interface()).ok_or("read: no map size")?;
    if original.is_empty() {
        return Err("metal map read back empty".to_string());
    }
    let cells = original.len() / 4;

    let mut pattern = Vec::with_capacity(cells * 4);
    for i in 0..cells {
        let amount = (i % 6) as f32; // 0..5, within the engine's metal range
        pattern.extend_from_slice(&amount.to_le_bytes());
    }
    write::write(ctx.sbc, &pattern);

    let read_back = read::read(ctx.sbc.interface()).ok_or("read after write: no map size")?;
    if read_back != pattern {
        let mismatch = pattern
            .chunks_exact(4)
            .zip(read_back.chunks_exact(4))
            .position(|(a, b)| a != b)
            .unwrap_or(0);
        return Err(format!("metal write/read mismatch at cell {mismatch}"));
    }

    let img = export::export(ctx.sbc.interface()).ok_or("export: no map size")?;
    if img.get_pixel(0, 0).0 != [0, 0, 0] {
        return Err(format!(
            "metal export cell (0,0) expected black (0 metal), got {:?}",
            img.get_pixel(0, 0).0
        ));
    }

    write::write(ctx.sbc, &original);
    Ok(())
}

crate::integration_test!("metal_ops_roundtrip", metal_ops_roundtrip);
