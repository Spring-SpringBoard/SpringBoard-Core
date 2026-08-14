use super::field_mutations::values_for_descriptors;
use super::test_support::{all_feature_defs, dispatch, first_feature_def};
use crate::sbc::objects::{codec, ObjectKind, ObjectManager};
use crate::sbc::tests::tests_api::TestCtx;
use serde_json::Value;
use spring_native::RulesParamValue;

/// Serialize every available feature def, replay the full objects, then ask
/// the feature model for valid values for every settable field.
fn set_object_param_feature(ctx: &mut TestCtx) -> Result<(), String> {
    let def_names = all_feature_defs(ctx)?;
    if def_names.is_empty() {
        return Err("no feature defs available in this engine boot".to_string());
    }

    let model_ids = add_all_feature_defs(ctx, &def_names)?;

    // A def may carry zero radius/height/reclaimTime, which the engine refuses
    // and clamps, so only the state after one replay is a fixed point.
    let before = replay_objects(ctx, &model_ids)?;
    let replayed = replay_objects(ctx, &model_ids)?;
    assert_objects_eq("full feature object replay", &before, &replayed)?;

    for (i, model_id) in model_ids.iter().enumerate() {
        let manager = ctx.sbc.model::<ObjectManager>();
        let descriptors = manager
            .field_descriptors(ObjectKind::Feature)
            .ok_or("no field descriptors for feature".to_string())?;
        let object = manager
            .get_full(ObjectKind::Feature, *model_id)
            .ok_or(format!("no full object for feature modelID {model_id}"))?;
        let Value::Object(current) = codec::object_to_json(&object) else {
            return Err(format!(
                "feature modelID {model_id} did not serialize to a JSON object"
            ));
        };
        let fields = values_for_descriptors(&descriptors, &current, i as u64 + 1);
        if fields.is_empty() {
            return Err(format!(
                "feature model produced no field descriptors for modelID {model_id}"
            ));
        }
        for field in fields {
            let before_field = read_field(ctx, ObjectKind::Feature, *model_id, field.field)?;
            dispatch(
                ctx,
                serde_json::json!({
                    "className": "SetObjectParamCommand",
                    "objType": "feature",
                    "modelID": model_id,
                    "key": field.field,
                    "value": field.value.clone()
                }),
            );
            let after_field = read_field(ctx, ObjectKind::Feature, *model_id, field.field)?;
            assert_field_changed_and_matches(
                "feature",
                *model_id,
                field.field,
                &before_field,
                &field.value,
                &after_field,
            )?;
        }
    }

    Ok(())
}

fn set_object_param_unit(ctx: &mut TestCtx) -> Result<(), String> {
    let ids = ctx
        .sbc
        .interface()
        .unit_defs()
        .get_unit_def_ids()
        .map_err(|e| format!("get_unit_def_ids: {e:?}"))?;
    if ids.is_empty() {
        log::info!("set_object_param_unit skipped: no unit defs in this engine boot");
        return Ok(());
    }
    Err("unit set/get mutation test needs a unit fixture in this smoke boot".to_string())
}

/// `SetObjectParamCommand` with key `"rules"` round-trips a mixed-type
/// name->value map (bool / number / string) through the engine.
fn feature_rules_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let def_name = first_feature_def(ctx)?;

    dispatch(
        ctx,
        serde_json::json!({
            "className": "AddObjectCommand",
            "objType": "feature",
            "params": {
                "defName": def_name,
                "pos": { "x": 256.0, "y": 0.0, "z": 256.0 }
            }
        }),
    );

    let model_id = ctx
        .sbc
        .model::<ObjectManager>()
        .latest_model_id(ObjectKind::Feature);
    let spring_id = ctx
        .sbc
        .model::<ObjectManager>()
        .spring_id(ObjectKind::Feature, model_id)
        .ok_or(format!("no springID for modelID {model_id} after add"))?;

    dispatch(
        ctx,
        serde_json::json!({
            "className": "SetObjectParamCommand",
            "objType": "feature",
            "modelID": model_id,
            "key": { "rules": { "hp_bonus": 42.0, "flagged": true, "label": "alpha" } }
        }),
    );

    let rules = ctx.sbc.interface().rules_params();

    let (num, _, exists) = rules
        .get_feature_rules_param(spring_id, "hp_bonus")
        .map_err(|e| format!("get hp_bonus: {e:?}"))?;
    if !exists {
        return Err("rule hp_bonus missing after set".to_string());
    }
    // Numeric rules come back as floats regardless of how stored.
    let RulesParamValue::Float(num_f) = num else {
        return Err(format!("hp_bonus came back as {num:?}, expected float"));
    };
    if (num_f - 42.0).abs() > 0.01 {
        return Err(format!("hp_bonus = {num_f}, expected 42"));
    }

    let (_label, _, label_exists) = rules
        .get_feature_rules_param(spring_id, "label")
        .map_err(|e| format!("get label: {e:?}"))?;
    if !label_exists {
        return Err("rule label missing after set".to_string());
    }

    Ok(())
}

fn add_all_feature_defs(ctx: &mut TestCtx, def_names: &[String]) -> Result<Vec<i32>, String> {
    let (hmx, hmz) = ctx
        .sbc
        .interface()
        .terrain()
        .get_height_map_size()
        .map_err(|e| format!("get_height_map_size: {e:?}"))?;
    let map_x = ((hmx - 1).max(1) * 8) as f32;
    let map_z = ((hmz - 1).max(1) * 8) as f32;
    let cols = (def_names.len() as f32).sqrt().ceil().max(1.0) as usize;
    let rows = def_names.len().div_ceil(cols);
    let step_x = (map_x / (cols as f32 + 1.0)).max(8.0);
    let step_z = (map_z / (rows as f32 + 1.0)).max(8.0);

    let mut model_ids = Vec::with_capacity(def_names.len());
    for (i, def_name) in def_names.iter().enumerate() {
        dispatch(
            ctx,
            serde_json::json!({
                "className": "AddObjectCommand",
                "objType": "feature",
                "params": {
                    "defName": def_name,
                    "team": 0,
                    "pos": {
                        "x": step_x * ((i % cols) as f32 + 1.0),
                        "y": 24.0 + (i % 5) as f32,
                        "z": step_z * ((i / cols) as f32 + 1.0)
                    },
                    "rot": {
                        "x": 0.03 * (i % 3) as f32,
                        "y": 0.17 + 0.07 * i as f32,
                        "z": 0.02 * (i % 4) as f32
                    },
                    "mass": 750.0 + i as f32
                }
            }),
        );

        let model_id = ctx
            .sbc
            .model::<ObjectManager>()
            .latest_model_id(ObjectKind::Feature);
        let spring_id = ctx
            .sbc
            .model::<ObjectManager>()
            .spring_id(ObjectKind::Feature, model_id)
            .ok_or(format!("no springID for feature def {def_name} after add"))?;
        if !ctx
            .sbc
            .interface()
            .features()
            .valid_feature_id(spring_id)
            .unwrap_or(false)
        {
            return Err(format!(
                "feature {spring_id} for def {def_name} is not valid"
            ));
        }
        model_ids.push(model_id);
    }
    Ok(model_ids)
}

fn replay_objects(ctx: &mut TestCtx, model_ids: &[i32]) -> Result<Vec<Value>, String> {
    let objects = read_objects(ctx, ObjectKind::Feature, model_ids, false)?;
    for (model_id, object) in model_ids.iter().zip(objects.iter()) {
        dispatch(
            ctx,
            serde_json::json!({
                "className": "SetObjectParamCommand",
                "objType": "feature",
                "modelID": model_id,
                "key": object
            }),
        );
    }
    read_objects(ctx, ObjectKind::Feature, model_ids, false)
}

fn read_objects(
    ctx: &mut TestCtx,
    kind: ObjectKind,
    model_ids: &[i32],
    full: bool,
) -> Result<Vec<Value>, String> {
    model_ids
        .iter()
        .map(|model_id| {
            let manager = ctx.sbc.model::<ObjectManager>();
            let object = if full {
                manager.get_full(kind, *model_id)
            } else {
                manager.get(kind, *model_id)
            };
            object
                .map(|object| codec::object_to_json(&object))
                .ok_or(format!("no object for {kind:?} modelID {model_id}"))
        })
        .collect()
}

fn read_field(
    ctx: &mut TestCtx,
    kind: ObjectKind,
    model_id: i32,
    field: &str,
) -> Result<Value, String> {
    let object = ctx
        .sbc
        .model::<ObjectManager>()
        .get_full(kind, model_id)
        .ok_or(format!("no full object for {kind:?} modelID {model_id}"))?;
    codec::object_to_json(&object)
        .get(field)
        .cloned()
        .ok_or(format!("{kind:?} modelID {model_id} missing field {field}"))
}

fn assert_field_changed_and_matches(
    kind: &str,
    model_id: i32,
    field: &str,
    before: &Value,
    expected: &Value,
    actual: &Value,
) -> Result<(), String> {
    let before = normalize_value(before);
    let expected = normalize_value(expected);
    let actual = normalize_value(actual);
    if before == actual {
        return Err(format!(
            "{kind} modelID {model_id} field {field} did not change after set: {actual}"
        ));
    }
    if expected != actual {
        return Err(format!(
            "{kind} modelID {model_id} field {field} mismatch after set:\nexpected: {expected}\nactual:   {actual}"
        ));
    }
    Ok(())
}

fn assert_objects_eq(label: &str, expected: &[Value], actual: &[Value]) -> Result<(), String> {
    let expected = normalize_objects(expected);
    let actual = normalize_objects(actual);
    if expected != actual {
        return Err(format!(
            "{label} changed serialized feature state:\nexpected: {}\nactual:   {}",
            Value::Array(expected),
            Value::Array(actual)
        ));
    }
    Ok(())
}

fn normalize_objects(values: &[Value]) -> Vec<Value> {
    values.iter().map(normalize_value).collect()
}

fn normalize_value(value: &Value) -> Value {
    match value {
        Value::Array(values) => Value::Array(values.iter().map(normalize_value).collect()),
        Value::Object(map) => Value::Object(
            map.iter()
                .map(|(key, value)| (key.clone(), normalize_value(value)))
                .collect(),
        ),
        Value::Number(n) => n
            .as_f64()
            .and_then(|v| serde_json::Number::from_f64((v * 1000.0).round() / 1000.0))
            .map(Value::Number)
            .unwrap_or_else(|| value.clone()),
        _ => value.clone(),
    }
}

crate::integration_test!("set_object_param", set_object_param_feature);
crate::integration_test!("set_object_param_units", set_object_param_unit);
crate::integration_test!("feature_rules_roundtrip", feature_rules_roundtrip);
