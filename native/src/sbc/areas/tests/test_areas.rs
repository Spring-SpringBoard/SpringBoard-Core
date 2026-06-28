use crate::sbc::areas::AreaManager;
use crate::sbc::tests::tests_api::TestCtx;

/// Resize an area via ResizeAreaCommand, then undo. AreaManager is the truth.
fn resize_area(ctx: &mut TestCtx) -> Result<(), String> {
    let id = ctx
        .sbc
        .model::<AreaManager>()
        .add_area(serde_json::json!([0.0, 0.0, 100.0, 100.0]), None);

    ctx.route_command(serde_json::json!({
        "className": "ResizeAreaCommand",
        "areaID": id,
        "x1": 10.0, "z1": 20.0, "x2": 200.0, "z2": 220.0
    }));

    expect_area(ctx, id, [10.0, 20.0, 200.0, 220.0])?;

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    expect_area(ctx, id, [0.0, 0.0, 100.0, 100.0])?;

    Ok(())
}

fn expect_area(ctx: &mut TestCtx, id: i32, want: [f32; 4]) -> Result<(), String> {
    let area = ctx
        .sbc
        .model::<AreaManager>()
        .get_area(id)
        .ok_or("area vanished")?;
    let arr = area.as_array().ok_or("area not an array")?;
    let got: Vec<f32> = arr
        .iter()
        .filter_map(|v| v.as_f64().map(|f| f as f32))
        .collect();
    if got.as_slice() != want {
        return Err(format!("area = {got:?}, expected {want:?}"));
    }
    Ok(())
}

crate::integration_test!("resize_area", resize_area);
