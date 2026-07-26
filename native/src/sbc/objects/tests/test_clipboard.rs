//! In-engine tests for the toolbar action layer's object operations: the
//! Copy, Cut, and Paste. They drive `actions::*` against the live models and
//! assert both the system clipboard contents and the engine-facing result.
//!
//! The whole integration suite shares one engine boot, so object modelIDs
//! accumulate across tests — never assume an absolute id. Each test identifies
//! the object it created by diffing the id set before and after.

use std::collections::HashSet;

use super::test_support::{dispatch, first_feature_def};
use crate::sbc::actions::{execute, execute_paste, Action, ActionResult};
use crate::sbc::objects::{ObjectKind, ObjectManager, SelectionManager};
use crate::sbc::tests::tests_api::TestCtx;

/// Add a feature, copy it, paste it elsewhere, and cut it. This covers the
/// action-layer work behind Ctrl+C/Ctrl+V/Ctrl+X, including the JSON handed to
/// the operating-system clipboard.
fn clipboard_copy_paste(ctx: &mut TestCtx) -> Result<(), String> {
    let def_name = first_feature_def(ctx)?;
    let mine = add_feature(ctx, &def_name, 320.0, 384.0)?;

    ctx.sbc
        .model::<SelectionManager>()
        .select_one(ObjectKind::Feature, mine);

    let iface = *ctx.sbc.interface();
    {
        let models = ctx.sbc.models_mut();
        let _ = execute(Action::Copy, &iface, models);
    }

    let copied = object_clipboard(ctx)?;
    assert_feature_clipboard(&copied, &def_name)?;

    // A valid empty payload must supersede the internal cache. That is what
    // makes Ctrl+V paste data from another SBC process rather than only the
    // most recent local Ctrl+C.
    iface
        .unsynced_ctrl()
        .set_clipboard(r#"{"format":"sbc-editor-objects","version":1,"objects":[]}"#)
        .map_err(|error| format!("set empty clipboard: {error:?}"))?;
    let empty_paste = {
        let models = ctx.sbc.models_mut();
        execute_paste(&iface, models, 900.0, 700.0)
    };
    if !empty_paste.is_empty() {
        return Err("Paste ignored the empty system object clipboard".to_string());
    }

    let copied_json = serde_json::to_string(&copied)
        .map_err(|error| format!("serialize copied object clipboard: {error}"))?;
    iface
        .unsynced_ctrl()
        .set_clipboard(&copied_json)
        .map_err(|error| format!("restore object clipboard: {error:?}"))?;

    let before_paste = feature_ids(ctx);
    let commands = {
        let models = ctx.sbc.models_mut();
        execute_paste(&iface, models, 900.0, 700.0)
    };
    if commands.is_empty() {
        return Err("paste produced no commands".to_string());
    }
    for command in commands {
        ctx.sbc.submit_command(command);
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

    let result = {
        let models = ctx.sbc.models_mut();
        execute(Action::Cut, &iface, models)
    };
    let ActionResult::NativeCommands(commands) = result else {
        return Err("Cut did not produce remove commands".to_string());
    };
    for command in commands {
        ctx.sbc.submit_command(command);
    }
    if ctx
        .sbc
        .model::<ObjectManager>()
        .spring_id(ObjectKind::Feature, mine)
        .is_some()
    {
        return Err("Cut left the selected feature in the engine".to_string());
    }
    assert_feature_clipboard(&object_clipboard(ctx)?, &def_name)?;
    Ok(())
}

fn object_clipboard(ctx: &TestCtx) -> Result<serde_json::Value, String> {
    let text = ctx
        .sbc
        .interface()
        .unsynced_read()
        .get_clipboard()
        .map_err(|error| format!("read object clipboard: {error:?}"))?
        .ok_or("object clipboard was empty")?;
    serde_json::from_str(&text).map_err(|error| format!("object clipboard was not JSON: {error}"))
}

fn assert_feature_clipboard(payload: &serde_json::Value, def_name: &str) -> Result<(), String> {
    if payload.get("format").and_then(serde_json::Value::as_str) != Some("sbc-editor-objects")
        || payload.get("version").and_then(serde_json::Value::as_u64) != Some(1)
    {
        return Err(format!("unexpected object clipboard envelope: {payload}"));
    }
    let objects = payload
        .get("objects")
        .and_then(serde_json::Value::as_array)
        .ok_or_else(|| format!("object clipboard did not contain an object array: {payload}"))?;
    let [object] = objects.as_slice() else {
        return Err(format!(
            "object clipboard contained {} objects, expected 1",
            objects.len()
        ));
    };
    if object.get("kind").and_then(serde_json::Value::as_str) != Some("feature")
        || object
            .pointer("/object/defName")
            .and_then(serde_json::Value::as_str)
            != Some(def_name)
    {
        return Err(format!(
            "object clipboard did not contain the copied feature: {object}"
        ));
    }
    if object.pointer("/object/__modelID").is_some() {
        return Err("object clipboard leaked __modelID".to_string());
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
    let result = {
        let models = ctx.sbc.models_mut();
        execute(Action::Delete, &iface, models)
    };
    let ActionResult::NativeCommands(commands) = result else {
        return Err("Delete did not produce commands".to_string());
    };
    for command in commands {
        ctx.sbc.submit_command(command);
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
