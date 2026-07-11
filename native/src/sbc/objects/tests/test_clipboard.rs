//! In-engine tests for the toolbar action layer's object operations: the
//! copy → paste round-trip and Delete. They drive `actions::*` against the live
//! models and assert the engine actually gained or lost the object.
//!
//! The whole integration suite shares one engine boot, so object modelIDs
//! accumulate across tests — never assume an absolute id. Each test identifies
//! the object it created by diffing the id set before and after.

use std::collections::HashSet;

use super::test_support::{dispatch, first_feature_def};
use crate::sbc::actions::{execute, execute_paste, Action, ActionResult};
use crate::sbc::objects::{ObjectKind, ObjectManager, SelectionManager};
use crate::sbc::tests::tests_api::TestCtx;

/// Add a feature, copy it, paste it elsewhere, and assert the pasted feature is
/// at the paste position — proving the clipboard's `object_json` →
/// `AddObjectCommand` round-trip (including `defName` and the position offset).
fn clipboard_copy_paste(ctx: &mut TestCtx) -> Result<(), String> {
    let def_name = first_feature_def(ctx)?;
    let mine = add_feature(ctx, &def_name, 320.0, 384.0)?;

    ctx.sbc
        .model::<SelectionManager>()
        .select_one(ObjectKind::Feature, mine);

    let iface = *ctx.sbc.interface();
    let mut next = 5_000_000u64;
    {
        let models = ctx.sbc.models_mut();
        let _ = execute(Action::Copy, &iface, models, &mut next);
    }

    let before_paste = feature_ids(ctx);
    let envelopes = {
        let models = ctx.sbc.models_mut();
        execute_paste(&iface, models, 900.0, 700.0, &mut next)
    };
    if envelopes.is_empty() {
        return Err("paste produced no command envelopes".to_string());
    }
    for env in &envelopes {
        ctx.sbc.route(env);
    }

    let pasted = single_new_id(&before_paste, &feature_ids(ctx))
        .ok_or("paste did not create exactly one new feature")?;
    let pos = feature_pos(ctx, pasted)?;
    if (pos.0 - 900.0).abs() > 2.0 || (pos.1 - 700.0).abs() > 2.0 {
        return Err(format!(
            "pasted feature at ({}, {}), expected x~900 z~700",
            pos.0, pos.1
        ));
    }
    Ok(())
}

/// Add a feature, select it, and run the Delete action — its `RemoveObjectCommand`
/// should drop the object.
fn delete_selection(ctx: &mut TestCtx) -> Result<(), String> {
    let def_name = first_feature_def(ctx)?;
    let mine = add_feature(ctx, &def_name, 256.0, 256.0)?;

    ctx.sbc
        .model::<SelectionManager>()
        .select_one(ObjectKind::Feature, mine);

    let iface = *ctx.sbc.interface();
    let mut next = 6_000_000u64;
    let result = {
        let models = ctx.sbc.models_mut();
        execute(Action::Delete, &iface, models, &mut next)
    };
    let ActionResult::Commands(envelopes) = result else {
        return Err("Delete did not produce commands".to_string());
    };
    for env in &envelopes {
        ctx.sbc.route(env);
    }

    if ctx
        .sbc
        .model::<ObjectManager>()
        .spring_id(ObjectKind::Feature, mine)
        .is_some()
    {
        return Err("Delete left the feature's modelID mapping".to_string());
    }
    Ok(())
}

/// Add a feature and return the new modelID (the one the id set gained).
fn add_feature(ctx: &mut TestCtx, def_name: &str, x: f32, z: f32) -> Result<i32, String> {
    let before = feature_ids(ctx);
    dispatch(
        ctx,
        serde_json::json!({
            "className": "AddObjectCommand",
            "objType": "feature",
            "params": {
                "defName": def_name,
                "pos": { "x": x, "y": 0.0, "z": z },
            }
        }),
    );
    single_new_id(&before, &feature_ids(ctx)).ok_or_else(|| "add created no feature".to_string())
}

fn feature_ids(ctx: &mut TestCtx) -> HashSet<i32> {
    ctx.sbc
        .model::<ObjectManager>()
        .all_model_ids(ObjectKind::Feature)
        .into_iter()
        .collect()
}

fn single_new_id(before: &HashSet<i32>, after: &HashSet<i32>) -> Option<i32> {
    let mut added = after.difference(before);
    let id = added.next().copied()?;
    added.next().is_none().then_some(id)
}

fn feature_pos(ctx: &mut TestCtx, model_id: i32) -> Result<(f32, f32), String> {
    let spring_id = ctx
        .sbc
        .model::<ObjectManager>()
        .spring_id(ObjectKind::Feature, model_id)
        .ok_or("no springID for the feature")?;
    let pos = ctx
        .sbc
        .interface()
        .features()
        .get_feature_position(spring_id)
        .map_err(|e| format!("get_feature_position: {e:?}"))?;
    Ok((pos.x, pos.z))
}

crate::integration_test!("clipboard_copy_paste", clipboard_copy_paste);
crate::integration_test!("delete_selection", delete_selection);
