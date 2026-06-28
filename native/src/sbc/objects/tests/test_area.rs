use super::test_support::dispatch;
use crate::sbc::objects::model::object_data::Vec3;
use crate::sbc::objects::{ObjectKind, ObjectManager};
use crate::sbc::tests::tests_api::TestCtx;

/// Areas are pure data (no engine object), so assert on the manager's stored
/// `{pos, size}`: add, resize via set-param + undo, then remove + undo.
fn area_add_set_remove(ctx: &mut TestCtx) -> Result<(), String> {
    dispatch(
        ctx,
        serde_json::json!({
            "className": "AddObjectCommand",
            "objType": "area",
            "params": {
                "pos": { "x": 300.0, "y": 0.0, "z": 400.0 },
                "size": { "x": 100.0, "y": 0.0, "z": 200.0 }
            }
        }),
    );

    let id = ctx
        .sbc
        .model::<ObjectManager>()
        .latest_model_id(ObjectKind::Area);

    expect_size_z(ctx, id, Some(200.0), "after add")?;

    dispatch(
        ctx,
        serde_json::json!({
            "className": "SetObjectParamCommand",
            "objType": "area",
            "modelID": id,
            "key": { "size": { "x": 100.0, "y": 0.0, "z": 50.0 } }
        }),
    );
    expect_size_z(ctx, id, Some(50.0), "after resize")?;

    dispatch(ctx, serde_json::json!({ "className": "UndoCommand" }));
    expect_size_z(ctx, id, Some(200.0), "after undo")?;

    dispatch(
        ctx,
        serde_json::json!({ "className": "RemoveObjectCommand", "objType": "area", "modelID": id }),
    );
    expect_size_z(ctx, id, None, "after remove")?;

    dispatch(ctx, serde_json::json!({ "className": "UndoCommand" }));
    expect_size_z(ctx, id, Some(200.0), "after remove-undo")
}

fn expect_size_z(ctx: &mut TestCtx, id: i32, want: Option<f64>, when: &str) -> Result<(), String> {
    let got = ctx
        .sbc
        .model::<ObjectManager>()
        .get(ObjectKind::Area, id)
        .and_then(|area| area.field_ref::<Vec3>("size").map(|size| size.z as f64));
    if got != want {
        return Err(format!("area size.z {when} = {got:?}, expected {want:?}"));
    }
    Ok(())
}

crate::integration_test!("area_add_set_remove", area_add_set_remove);
