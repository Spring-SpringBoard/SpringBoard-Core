use crate::sbc::objects::Vec3;
use crate::sbc::objects::{ObjectKind, ObjectManager};
use crate::sbc::tests::tests_api::TestCtx;

fn resize_area(ctx: &mut TestCtx) -> Result<(), String> {
    ctx.route_command(serde_json::json!({
        "className": "AddObjectCommand",
        "objType": "area",
        "params": {
            "pos": { "x": 300.0, "y": 0.0, "z": 400.0 },
            "size": { "x": 100.0, "y": 0.0, "z": 200.0 }
        }
    }));

    let id = ctx
        .sbc
        .model::<ObjectManager>()
        .latest_model_id(ObjectKind::Area);

    ctx.route_command(serde_json::json!({
        "className": "ResizeAreaCommand",
        "areaID": id,
        "x1": 10.0,
        "z1": 20.0,
        "x2": 200.0,
        "z2": 220.0
    }));
    expect_area(ctx, id, (105.0, 120.0), (190.0, 200.0), "after resize")?;

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    expect_area(ctx, id, (300.0, 400.0), (100.0, 200.0), "after undo")?;

    ctx.route_command(serde_json::json!({ "className": "RedoCommand" }));
    expect_area(ctx, id, (105.0, 120.0), (190.0, 200.0), "after redo")
}

fn expect_area(
    ctx: &mut TestCtx,
    id: i32,
    want_pos: (f32, f32),
    want_size: (f32, f32),
    when: &str,
) -> Result<(), String> {
    let area = ctx
        .sbc
        .model::<ObjectManager>()
        .get(ObjectKind::Area, id)
        .ok_or_else(|| format!("area vanished {when}"))?;
    let pos = area
        .field_ref::<Vec3>("pos")
        .ok_or_else(|| format!("missing pos {when}"))?;
    let size = area
        .field_ref::<Vec3>("size")
        .ok_or_else(|| format!("missing size {when}"))?;

    let got_pos = (pos.x, pos.z);
    let got_size = (size.x, size.z);
    if got_pos != want_pos || got_size != want_size {
        return Err(format!(
            "area {when}: pos {got_pos:?}, size {got_size:?}; expected {want_pos:?}, {want_size:?}"
        ));
    }
    Ok(())
}

crate::integration_test!("resize_area", resize_area);
