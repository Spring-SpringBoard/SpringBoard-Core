//! The generic UnitDef property API.
//!
//! The native interface used to expose a hand-picked subset of UnitDef, so any
//! property nobody had needed yet was simply unreachable — the Objects def
//! filters were blocked on four of them. `GetUnitDefParam*` reads the same
//! reflection table Lua reads (`LuaUnitDefs::GetParamMap`), so every property
//! `UnitDefs[id].foo` has is reachable as `get_unit_def_param_*(id, "foo")`.
//!
//! These fail without that binding: the calls do not exist.

use crate::sbc::tests::tests_api::TestCtx;

/// The engine's unit defs, or an empty list in a boot that has none.
fn unit_def_ids(ctx: &TestCtx) -> Vec<i32> {
    ctx.sbc
        .interface()
        .unit_defs()
        .get_unit_def_ids()
        .unwrap_or_default()
}

/// The property table must be non-trivial, and it must carry the properties the
/// old struct API left out. Anything less and we are back to a curated subset.
fn unit_def_params_expose_the_whole_table(ctx: &mut TestCtx) -> Result<(), String> {
    let defs = ctx.sbc.interface().unit_defs();

    let keys = defs
        .get_unit_def_param_keys()
        .map_err(|e| format!("get_unit_def_param_keys: {e:?}"))?;

    // Lua's table has 200+ entries; the old struct API had ~30 fields total.
    if keys.len() < 100 {
        return Err(format!(
            "expected the full UnitDef table (200+ properties), got {}",
            keys.len()
        ));
    }

    let names: Vec<String> = keys
        .iter()
        .filter_map(|key| {
            (!key.name.is_null())
                .then(|| unsafe { std::ffi::CStr::from_ptr(key.name) })
                .map(|name| name.to_string_lossy().into_owned())
        })
        .collect();

    // The four that blocked the Objects def filters, plus a computed classifier.
    for wanted in [
        "isBuilding",
        "canSubmerge",
        "waterline",
        "minWaterDepth",
        "canFly",
    ] {
        if !names.iter().any(|name| name == wanted) {
            return Err(format!("UnitDef property {wanted} is not exposed"));
        }
    }
    Ok(())
}

/// A property read by name must agree with the same property read through the
/// typed struct call. If they disagree, the offsets are being misread.
fn unit_def_params_agree_with_the_typed_api(ctx: &mut TestCtx) -> Result<(), String> {
    let ids = unit_def_ids(ctx);
    let Some(&id) = ids.first() else {
        // A boot with no unit defs (the standalone smoke map) cannot check this.
        return Ok(());
    };

    let defs = ctx.sbc.interface().unit_defs();
    let (_, _, _, physics, ..) = defs
        .get_unit_def_by_id(id)
        .map_err(|e| format!("get_unit_def_by_id({id}): {e:?}"))?;

    let can_fly = defs
        .get_unit_def_param_bool(id, "canFly")
        .map_err(|e| format!("get_unit_def_param_bool(canFly): {e:?}"))?;
    if can_fly != physics.canFly {
        return Err(format!(
            "canFly disagrees: by name {can_fly}, by struct {}",
            physics.canFly
        ));
    }

    let waterline = defs
        .get_unit_def_param_float(id, "waterline")
        .map_err(|e| format!("get_unit_def_param_float(waterline): {e:?}"))?;
    if (waterline - physics.waterline).abs() > f32::EPSILON {
        return Err(format!(
            "waterline disagrees: by name {waterline}, by struct {}",
            physics.waterline
        ));
    }

    // `isBuilding` is computed by UnitDef, not stored, so it has no offset to
    // read -- it is served by calling the def. It must still answer by name, and
    // it must match the classification call.
    let is_building = defs
        .get_unit_def_param_bool(id, "isBuilding")
        .map_err(|e| format!("get_unit_def_param_bool(isBuilding): {e:?}"))?;
    let classify = defs
        .get_unit_def_classify(id)
        .map_err(|e| format!("get_unit_def_classify({id}): {e:?}"))?;
    if is_building != classify.isBuilding {
        return Err(format!(
            "isBuilding disagrees: by name {is_building}, by classify {}",
            classify.isBuilding
        ));
    }
    Ok(())
}

/// A property that does not exist must report itself missing rather than read a
/// wild offset.
fn an_unknown_unit_def_param_is_an_error(ctx: &mut TestCtx) -> Result<(), String> {
    let ids = unit_def_ids(ctx);
    let Some(&id) = ids.first() else {
        return Ok(());
    };

    let defs = ctx.sbc.interface().unit_defs();
    if defs.get_unit_def_param_bool(id, "noSuchProperty").is_ok() {
        return Err("an unknown property must not read as a value".to_string());
    }
    // Reading a float as a bool is the same mistake, and must also be refused.
    if defs.get_unit_def_param_bool(id, "waterline").is_ok() {
        return Err("a float must not read as a bool".to_string());
    }
    Ok(())
}

crate::integration_test!(
    "unit_def_params_expose_the_whole_table",
    unit_def_params_expose_the_whole_table
);
crate::integration_test!(
    "unit_def_params_agree_with_the_typed_api",
    unit_def_params_agree_with_the_typed_api
);
crate::integration_test!(
    "an_unknown_unit_def_param_is_an_error",
    an_unknown_unit_def_param_is_an_error
);
