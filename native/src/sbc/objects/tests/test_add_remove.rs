use super::test_support::{dispatch, first_feature_def};
use crate::sbc::objects::{ObjectKind, ObjectManager};
use crate::sbc::tests::tests_api::TestCtx;

/// Add a feature, verify it in the engine, then undo (destroys it) and redo.
/// The engine is the source of truth, so query `get_feature_*`, not the cache.
fn feature_add_remove(ctx: &mut TestCtx) -> Result<(), String> {
    let def_name = first_feature_def(ctx)?;

    dispatch(
        ctx,
        serde_json::json!({
            "className": "AddObjectCommand",
            "objType": "feature",
            "params": {
                "defName": def_name,
                "pos": { "x": 320.0, "y": 0.0, "z": 384.0 },
                "rot": { "x": 0.0, "y": 1.5, "z": 0.0 },
                "mass": 1234.0,
                "radiusHeight": { "radius": 40.0, "height": 80.0 }
            }
        }),
    );

    let model_id = 1;
    let spring_id = ctx
        .sbc
        .model::<ObjectManager>()
        .spring_id(ObjectKind::Feature, model_id)
        .ok_or("no springID for modelID 1 after add")?;

    {
        let features = ctx.sbc.interface().features();
        if !features.valid_feature_id(spring_id).unwrap_or(false) {
            return Err(format!("feature {spring_id} not valid after add"));
        }
        let pos = features
            .get_feature_position(spring_id)
            .map_err(|e| format!("get_feature_position: {e:?}"))?;
        // Features snap to ground height, so check x/z only.
        if (pos.x - 320.0).abs() > 1.0 || (pos.z - 384.0).abs() > 1.0 {
            return Err(format!(
                "feature pos = ({}, {}), expected x~320 z~384",
                pos.x, pos.z
            ));
        }

        let mass = features
            .get_feature_mass(spring_id)
            .map_err(|e| format!("get_feature_mass: {e:?}"))?;
        if (mass - 1234.0).abs() > 0.5 {
            return Err(format!("feature mass = {mass}, expected 1234"));
        }

        let rot = features
            .get_feature_rotation(spring_id)
            .map_err(|e| format!("get_feature_rotation: {e:?}"))?;
        if (rot.yaw - 1.5).abs() > 0.05 {
            return Err(format!("feature rot.yaw = {}, expected 1.5", rot.yaw));
        }

        let radius = features
            .get_feature_radius(spring_id)
            .map_err(|e| format!("get_feature_radius: {e:?}"))?;
        let height = features
            .get_feature_height(spring_id)
            .map_err(|e| format!("get_feature_height: {e:?}"))?;
        if (radius - 40.0).abs() > 0.5 || (height - 80.0).abs() > 0.5 {
            return Err(format!(
                "feature radius/height = {radius}/{height}, expected 40/80"
            ));
        }
    }

    // Engine defers the actual delete to the next sim frame and SBC is paused, so
    // `valid_feature_id` may still be true — assert on the modelID mapping, which
    // the manager drops synchronously.
    dispatch(ctx, serde_json::json!({ "className": "UndoCommand" }));
    if ctx
        .sbc
        .model::<ObjectManager>()
        .spring_id(ObjectKind::Feature, model_id)
        .is_some()
    {
        return Err("undo of add left the modelID mapping".to_string());
    }

    dispatch(ctx, serde_json::json!({ "className": "RedoCommand" }));
    let spring_id2 = ctx
        .sbc
        .model::<ObjectManager>()
        .spring_id(ObjectKind::Feature, model_id)
        .ok_or("no springID for modelID 1 after redo")?;
    if !ctx
        .sbc
        .interface()
        .features()
        .valid_feature_id(spring_id2)
        .unwrap_or(false)
    {
        return Err(format!("feature {spring_id2} not valid after redo"));
    }

    Ok(())
}

crate::integration_test!("feature_add_remove", feature_add_remove);
