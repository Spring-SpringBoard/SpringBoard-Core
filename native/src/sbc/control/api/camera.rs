use serde::Deserialize;
use serde_json::json;

use crate::sbc::sbc::SBC;

use super::super::{ControlError, Handled, Reply};

#[derive(Deserialize)]
pub(crate) struct Set {
    pub position: Option<[f32; 3]>,
    pub controller_position: Option<[f32; 3]>,
    pub direction: Option<[f32; 3]>,
    pub fov: Option<f32>,
    pub height: Option<f32>,
    pub angle: Option<f32>,
    pub distance: Option<f32>,
    pub target: Option<[f32; 3]>,
    #[serde(default)]
    pub transition: f32,
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
            .set_camera_target(
                target,
                spring_native::SetCameraTargetOptions {
                    transition_time: Some(params.transition),
                    ..Default::default()
                },
            )
            .map_err(|err| ControlError::failed(format!("set_camera_target: {err:?}")))?;
    }
    get(sbc)
}
