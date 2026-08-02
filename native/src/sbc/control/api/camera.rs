//! `camera.*`: where the view is, so a capture can frame what it is about.

use serde::Deserialize;
use serde_json::json;
use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::sbc::SBC;

use super::super::{ControlError, Handled, Reply};

#[derive(Deserialize)]
pub(crate) struct Set {
    pub position: Option<[f32; 3]>,
    /// The controller/map position (`px/py/pz`) returned by `camera.get`.
    /// Unlike `position`, this is not the rendered camera position.
    pub controller_position: Option<[f32; 3]>,
    pub direction: Option<[f32; 3]>,
    pub fov: Option<f32>,
    pub height: Option<f32>,
    pub angle: Option<f32>,
    pub distance: Option<f32>,
    /// Kept for compatibility with the lower-level engine API. New callers
    /// should use `position` and `direction`, whose meanings are explicit.
    pub target: Option<[f32; 3]>,
    #[serde(default)]
    pub transition: f32,
}

#[derive(Deserialize)]
pub(crate) struct Zoom {
    pub factor: f32,
    /// Keep this ground point under a screen-space cursor while zooming.
    /// This is the semantic equivalent of the engine's mouse-wheel zoom; the
    /// client should pass the screen point, not reproduce camera geometry.
    #[serde(default)]
    pub screen: Option<[f32; 2]>,
}

#[derive(Deserialize)]
pub(crate) struct Trace {
    pub screen: [f32; 2],
}

pub(crate) fn get(sbc: &mut SBC) -> Handled {
    let camera = sbc.interface().camera();
    let state = camera
        .get_camera_state(false)
        .map_err(|err| ControlError::failed(format!("get_camera_state: {err:?}")))?;
    let position = camera
        .get_camera_position()
        .map_err(|err| ControlError::failed(format!("get_camera_position: {err:?}")))?;
    let direction = camera
        .get_camera_direction()
        .map_err(|err| ControlError::failed(format!("get_camera_direction: {err:?}")))?;
    Ok(Reply::now(json!({
        // `position` is the rendered camera position. The controller state is
        // returned separately because overhead/spring cameras keep their
        // ground focus in `px/py/pz` and derive the rendered position from it.
        "position": [position.x, position.y, position.z],
        "controller_position": [state.pos.x, state.pos.y, state.pos.z],
        "direction": [direction.x, direction.y, direction.z],
        "fov": state.fov,
        "height": state.height,
        "angle": state.angle,
        "distance": state.dist,
        "rotation": [state.rx, state.ry, state.rz],
    })))
}

pub(crate) fn set(sbc: &mut SBC, params: Set) -> Handled {
    if params.position.is_none()
        && params.controller_position.is_none()
        && params.direction.is_none()
        && params.fov.is_none()
        && params.height.is_none()
        && params.angle.is_none()
        && params.distance.is_none()
        && params.target.is_none()
    {
        return Err(ControlError::invalid(
            "camera.set needs at least one camera field",
        ));
    }
    let camera = sbc.interface().camera();
    let mut state = camera
        .get_camera_state(false)
        .map_err(|err| ControlError::failed(format!("get_camera_state: {err:?}")))?;
    if let Some(height) = params.height {
        if !height.is_finite() || height <= 0.0 {
            return Err(ControlError::invalid(
                "camera.set height must be positive and finite",
            ));
        }
        state.height = height;
    }
    if let Some(angle) = params.angle {
        if !angle.is_finite() || angle <= 0.0 {
            return Err(ControlError::invalid(
                "camera.set angle must be positive and finite",
            ));
        }
        state.angle = angle;
    }
    if let Some(distance) = params.distance {
        if !distance.is_finite() || distance <= 0.0 {
            return Err(ControlError::invalid(
                "camera.set distance must be positive and finite",
            ));
        }
        state.dist = distance;
    }
    if let Some([x, y, z]) = params.controller_position {
        if !x.is_finite() || !y.is_finite() || !z.is_finite() {
            return Err(ControlError::invalid(
                "camera.set controller_position must be finite",
            ));
        }
        state.pos.x = x;
        state.pos.y = y;
        state.pos.z = z;
    } else if let Some([x, y, z]) = params.position {
        if !x.is_finite() || !y.is_finite() || !z.is_finite() {
            return Err(ControlError::invalid("camera.set position must be finite"));
        }
        // The native CameraState mirrors Spring's controller map. Convert the
        // public rendered position back to that map for cameras whose position
        // is derived from a ground focus and a distance/height.
        let direction = params
            .direction
            .unwrap_or([state.dir.x, state.dir.y, state.dir.z]);
        let offset = if state.height > 0.0 {
            state.height
        } else {
            state.dist
        };
        state.pos.x = x + direction[0] * offset;
        state.pos.y = y + direction[1] * offset;
        state.pos.z = z + direction[2] * offset;
    }
    if let Some([x, y, z]) = params.direction {
        if !x.is_finite() || !y.is_finite() || !z.is_finite() {
            return Err(ControlError::invalid("camera.set direction must be finite"));
        }
        state.dir.x = x;
        state.dir.y = y;
        state.dir.z = z;
    }
    if let Some(fov) = params.fov {
        if !fov.is_finite() || fov <= 0.0 {
            return Err(ControlError::invalid(
                "camera.set fov must be positive and finite",
            ));
        }
        state.fov = fov;
    }
    camera
        .set_camera_state(state, params.transition, 1.0, 1.0)
        .map_err(|err| ControlError::failed(format!("set_camera_state: {err:?}")))?
        .then_some(())
        .ok_or_else(|| ControlError::failed("engine rejected camera state"))?;

    if let Some([x, y, z]) = params.target {
        let target = spring_native::prelude::sys::Float3 { x, y, z };
        camera
            .set_camera_target(target, params.transition)
            .map_err(|err| ControlError::failed(format!("set_camera_target: {err:?}")))?;
    }
    get(sbc)
}

pub(crate) fn zoom(sbc: &mut SBC, params: Zoom) -> Handled {
    if !params.factor.is_finite() || params.factor <= 0.0 {
        return Err(ControlError::invalid(
            "camera.zoom factor must be positive and finite",
        ));
    }
    let interface = sbc.interface();
    let target = if let Some(screen) = params.screen {
        if !screen[0].is_finite() || !screen[1].is_finite() {
            return Err(ControlError::invalid(
                "camera.zoom screen coordinates must be finite",
            ));
        }
        trace_ground(interface, screen)?
    } else {
        None
    };
    let camera = interface.camera();
    let mut state = camera
        .get_camera_state(false)
        .map_err(|err| ControlError::failed(format!("get_camera_state: {err:?}")))?;
    if state.height > 0.0 {
        state.height *= params.factor;
    } else if state.dist > 0.0 {
        state.dist *= params.factor;
    } else {
        // Free/first-person cameras have no controller distance. Optical zoom
        // is deterministic and, unlike scaling the world position, cannot
        // teleport the view to an unrelated part of the map.
        state.fov = (state.fov * params.factor).clamp(1.0, 179.0);
    }
    camera
        .set_camera_state(state, 0.0, 1.0, 1.0)
        .map_err(|err| ControlError::failed(format!("set_camera_state: {err:?}")))?
        .then_some(())
        .ok_or_else(|| ControlError::failed("engine rejected camera zoom"))?;

    if let (Some(screen), Some(target)) = (params.screen, target) {
        // The generic camera.zoom operation scales around the controller
        // position. The mouse-wheel operation instead keeps the traced ground
        // point beneath the cursor. Re-trace after scaling and apply the
        // horizontal ground delta in the controller, where the engine owns the
        // camera projection and terrain height.
        if let Some(current) = trace_ground(interface, screen)? {
            let mut state = camera
                .get_camera_state(false)
                .map_err(|err| ControlError::failed(format!("get_camera_state: {err:?}")))?;
            state.pos.x += target[0] - current[0];
            state.pos.z += target[2] - current[2];
            camera
                .set_camera_state(state, 0.0, 1.0, 1.0)
                .map_err(|err| ControlError::failed(format!("set_camera_state: {err:?}")))?
                .then_some(())
                .ok_or_else(|| ControlError::failed("engine rejected camera focus"))?;
        }
    }
    get(sbc)
}

pub(crate) fn trace(sbc: &mut SBC, params: Trace) -> Handled {
    let [x, y] = params.screen;
    if !x.is_finite() || !y.is_finite() {
        return Err(ControlError::invalid(
            "camera.trace screen coordinates must be finite",
        ));
    }
    let (hit_type, hit_id, position) = sbc
        .interface()
        .camera()
        .trace_screen_ray(x, y, true, false, false, true, 0.0)
        .map_err(|err| ControlError::failed(format!("trace_screen_ray: {err:?}")))?;
    Ok(Reply::now(json!({
        "hit_type": hit_type,
        "hit_id": hit_id,
        "position": [position.x, position.y, position.z],
    })))
}

fn trace_ground(
    interface: &NativeInterfaceRef,
    screen: [f32; 2],
) -> Result<Option<[f32; 3]>, ControlError> {
    let (hit_type, _, position) = interface
        .camera()
        .trace_screen_ray(screen[0], screen[1], true, false, false, true, 0.0)
        .map_err(|err| ControlError::failed(format!("trace_screen_ray: {err:?}")))?;
    Ok((hit_type == 3).then_some([position.x, position.y, position.z]))
}
