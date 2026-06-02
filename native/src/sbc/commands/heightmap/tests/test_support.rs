use crate::sbc::tests::tests_api::TestCtx;

pub const SQUARE_SIZE: f32 = 8.0;

pub fn register_full_brush(ctx: &mut TestCtx, name: &str) -> (usize, usize) {
    let (sx, sz) = (33usize, 33usize);
    let mut res = serde_json::Map::new();
    for i in 0..(sx * sz) {
        res.insert(i.to_string(), serde_json::json!(1.0));
    }
    ctx.sbc.route(
        &serde_json::json!({
            "tag": "command",
            "data": {
                "className": "SetHeightmapBrushCommand",
                "greyscale": { "res": res, "sizeX": sx, "sizeZ": sz, "name": name }
            }
        })
        .to_string(),
    );
    (sx, sz)
}

pub fn seed_flat(ctx: &mut TestCtx, cx: f32, cz: f32, reach: f32, height: f32) {
    let interface = ctx.sbc.interface();
    let synced = interface.synced_ctrl();
    let terrain = synced.terrain();
    let _ = terrain.set_height_map_func(|| {
        let mut x = cx - reach;
        while x <= cx + reach {
            let mut z = cz - reach;
            while z <= cz + reach {
                let _ = terrain.set_height_map(x, z, height, 1.0);
                z += SQUARE_SIZE;
            }
            x += SQUARE_SIZE;
        }
    });
}

pub fn ground_height(ctx: &mut TestCtx, x: f32, z: f32, label: &str) -> Result<f32, String> {
    ctx.sbc
        .interface()
        .terrain()
        .get_ground_height(x, z)
        .map_err(|e| format!("get_ground_height {label}: {e:?}"))
}

pub fn min_normal_y_across(ctx: &mut TestCtx, cx: f32, cz: f32, reach: f32) -> Result<f32, String> {
    let mut worst = 1.0_f32;
    let mut x = cx - reach;
    while x <= cx + reach {
        let ny = ground_normal_y(ctx, x, cz)?;
        worst = worst.min(ny);
        x += SQUARE_SIZE;
    }
    Ok(worst)
}

fn ground_normal_y(ctx: &mut TestCtx, x: f32, z: f32) -> Result<f32, String> {
    let (normal, _slope) = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_normal(x, z, true)
        .map_err(|e| format!("get_ground_normal: {e:?}"))?;
    Ok(normal.y)
}
