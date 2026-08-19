use serde::Deserialize;
use serde_json::json;

use crate::sbc::sbc::SBC;

use super::super::{ControlError, Handled, Reply};

#[derive(Deserialize)]
pub(crate) struct Echo {
    pub message: String,
    #[serde(default)]
    pub level: i32,
}

pub(crate) fn echo(sbc: &mut SBC, params: Echo) -> Handled {
    sbc.interface()
        .messages()
        .log("", params.level, &params.message)
        .map_err(|err| ControlError::failed(format!("{err:?}")))?;
    Ok(Reply::now(json!({})))
}
