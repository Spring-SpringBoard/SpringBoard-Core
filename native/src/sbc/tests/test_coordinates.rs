//! Coordinate-contract integration coverage for the native and Lua ray paths.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde_json::Value;

use crate::sbc::states::trace::{trace_screen_ray, ScreenTrace, TraceOptions};
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::{lua_bridge, sbc::SBC};

fn native_and_lua_trace_screen_ray_match(ctx: &mut TestCtx) -> Result<(), String> {
    let geometry = ctx
        .sbc
        .interface()
        .display()
        .get_view_geometry()
        .map_err(|err| format!("get_view_geometry: {err:?}"))?;
    let x = (geometry.viewSizeX / 2) as f32;
    let height = geometry.viewSizeY.max(8);
    let candidate_ys = [
        height / 8,
        height / 4,
        height / 3,
        height / 2,
        height * 2 / 3,
        height * 3 / 4,
        height * 7 / 8,
    ];

    // Pick two asymmetric points that are actually on the map in this camera
    // setup. The Lua comparison below still receives the exact same points;
    // this avoids making the test depend on a particular camera height while
    // retaining sensitivity to a vertical mirror.
    let mut points = Vec::new();
    let mut native_results = Vec::new();
    for y in candidate_ys {
        let point = [x, y as f32];
        let trace = trace_screen_ray(
            ctx.sbc.interface(),
            point[0],
            point[1],
            TraceOptions::ground(true),
        )
        .map_err(|err| format!("trace_screen_ray({point:?}): {err:?}"))?;
        if trace.hit_type == 3 {
            points.push(point);
            native_results.push(trace);
        }
    }
    if points.len() < 2 {
        return Err(format!(
            "fewer than two candidate screen points hit ground: {:?}",
            candidate_ys
        ));
    }
    let first = native_results.first().ok_or("missing first native trace")?;
    let last = native_results.last().ok_or("missing last native trace")?;
    if points.first() == points.last() || first.position == last.position {
        return Err("candidate screen points did not produce distinct ground hits".to_string());
    }

    let token = format!(
        "trace-{}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|err| format!("clock: {err}"))?
            .as_nanos()
    );
    forget_result(&token);
    lua_bridge::widget_command(
        ctx.sbc.interface(),
        serde_json::json!({
            "className": "TraceScreenRayParityCommand",
            "token": token,
            "points": points,
        }),
    );

    if !ctx.wait_for_io(Duration::from_secs(5), |_| result_seen(&token)) {
        return Err("Lua TraceScreenRay parity response did not arrive".to_string());
    }
    let lua_results = take_result(&token).ok_or("Lua parity response disappeared")?;
    compare_lua_results(&points, &native_results, &lua_results)
}

crate::integration_test!(
    "native_and_lua_trace_screen_ray_match",
    native_and_lua_trace_screen_ray_match
);

fn compare_lua_results(
    points: &[[f32; 2]],
    native_results: &[ScreenTrace],
    lua_results: &Value,
) -> Result<(), String> {
    let results = lua_results
        .get("results")
        .and_then(Value::as_array)
        .ok_or("Lua parity response has no results array")?;
    if results.len() != points.len() || native_results.len() != points.len() {
        return Err(format!(
            "trace result length mismatch: points={}, native={}, lua={}",
            points.len(),
            native_results.len(),
            results.len()
        ));
    }

    for (index, (native, lua)) in native_results.iter().zip(results).enumerate() {
        let kind = lua
            .get("kind")
            .and_then(Value::as_str)
            .ok_or_else(|| format!("Lua trace {index} has no kind"))?;
        if kind != "ground" || native.hit_type != 3 {
            return Err(format!(
                "trace {:?} disagrees on hit type: native={}, lua={kind}",
                points[index], native.hit_type
            ));
        }
        let coords = lua
            .get("coords")
            .and_then(Value::as_array)
            .ok_or_else(|| format!("Lua trace {index} has no coordinates"))?;
        for (axis, expected) in [native.position.x, native.position.y, native.position.z]
            .into_iter()
            .enumerate()
        {
            let actual = coords
                .get(axis)
                .and_then(Value::as_f64)
                .ok_or_else(|| format!("Lua trace {index} coordinate {axis} is invalid"))?
                as f32;
            if (actual - expected).abs() > 0.01 {
                return Err(format!(
                    "trace {:?} coordinate {axis} differs: native={expected}, lua={actual}",
                    points[index]
                ));
            }
        }
    }
    Ok(())
}

fn results() -> &'static Mutex<HashMap<String, Value>> {
    static RESULTS: OnceLock<Mutex<HashMap<String, Value>>> = OnceLock::new();
    RESULTS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn result_seen(token: &str) -> bool {
    results()
        .lock()
        .is_ok_and(|values| values.contains_key(token))
}

fn take_result(token: &str) -> Option<Value> {
    results().lock().ok()?.remove(token)
}

fn forget_result(token: &str) {
    if let Ok(mut values) = results().lock() {
        values.remove(token);
    }
}

fn receive_result(_sbc: &mut SBC, data: Value) {
    let Some(token) = data.get("token").and_then(Value::as_str) else {
        log::error!("TraceScreenRay parity message has no token");
        return;
    };
    if let Ok(mut values) = results().lock() {
        values.insert(token.to_string(), data);
    }
}

inventory::submit! {
    crate::sbc::message_handler::MessageHandler {
        tag: "trace_screen_ray_parity",
        handler: receive_result,
    }
}
