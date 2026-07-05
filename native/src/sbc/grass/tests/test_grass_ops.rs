use crate::sbc::grass::ops::{export, read, write};
use crate::sbc::tests::tests_api::TestCtx;

fn grass_ops_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let original = read::read(ctx.sbc.interface()).ok_or("read: no map size")?;
    if original.is_empty() {
        return Err("grass map read back empty".to_string());
    }

    let pattern: Vec<u8> = (0..original.len()).map(|i| (i % 2) as u8).collect();
    write::write(ctx.sbc, &pattern);

    let read_back = read::read(ctx.sbc.interface()).ok_or("read after write: no map size")?;
    if read_back != pattern {
        let mismatch = pattern
            .iter()
            .zip(&read_back)
            .position(|(a, b)| a != b)
            .unwrap_or(0);
        return Err(format!(
            "grass write/read mismatch at cell {mismatch}: wrote {}, read {}",
            pattern[mismatch], read_back[mismatch]
        ));
    }

    let img = export::export(ctx.sbc.interface()).ok_or("export: no map size")?;
    if img.get_pixel(0, 0).0 != [0, 0, 0] {
        return Err(format!(
            "grass export cell (0,0) expected black (no grass), got {:?}",
            img.get_pixel(0, 0).0
        ));
    }

    write::write(ctx.sbc, &original);
    Ok(())
}

crate::integration_test!("grass_ops_roundtrip", grass_ops_roundtrip);
