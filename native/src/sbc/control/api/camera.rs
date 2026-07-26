//! `camera.*`: where the view is, so a capture can frame what it is about.

use serde::Deserialize;
use serde_json::json;

use crate::sbc::sbc::SBC;

use super::super::{ControlError, Handled, Reply};

#[derive(Deserialize)]
pub(crate) struct Set {
    pub position: Option<[f32; 3]>,
    pub target: Option<[f32; 3]>,
    #[serde(default)]
    pub transition: f32,
}

pub(crate) fn get(sbc: &mut SBC) -> Handled {
    let camera = sbc.interface().camera();
    let (Ok(position), Ok(direction), Ok(fov)) = (
        camera.get_camera_position(),
        camera.get_camera_direction(),
        camera.get_camera_fov(),
    ) else {
        return Err(ControlError::failed(
            "the engine did not report a camera state",
        ));
    };
    Ok(Reply::now(json!({
        "position": [position.x, position.y, position.z],
        "direction": [direction.x, direction.y, direction.z],
        "fov": fov,
    })))
}

pub(crate) fn set(sbc: &mut SBC, params: Set) -> Handled {
    if params.position.is_none() && params.target.is_none() {
        return Err(ControlError::invalid(
            "camera.set needs a `position`, a `target`, or both",
        ));
    }
    let camera = sbc.interface().camera();
    if let Some([x, y, z]) = params.position {
        let mut state = camera
            .get_camera_state(false)
            .map_err(|err| ControlError::failed(format!("get_camera_state: {err:?}")))?;
        state.pos.x = x;
        state.pos.y = y;
        state.pos.z = z;
        // The name pointer belongs to the engine's own reply; keeping it makes
        // this a modification of the current camera rather than a new one.
        camera
            .set_camera_state(state, params.transition, 1.0, 1.0)
            .map_err(|err| ControlError::failed(format!("set_camera_state: {err:?}")))?;
    }
    if let Some([x, y, z]) = params.target {
        let target = spring_native::prelude::sys::Float3 { x, y, z };
        camera
            .set_camera_target(target, params.transition)
            .map_err(|err| ControlError::failed(format!("set_camera_target: {err:?}")))?;
    }
    get(sbc)
}
