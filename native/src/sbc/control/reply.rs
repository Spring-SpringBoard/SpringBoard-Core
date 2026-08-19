use serde_json::Value;

use super::channel::Effect;
use super::ControlError;

pub(crate) enum Reply {
    Now(Value),
    When(Effect),
}

impl Reply {
    pub(crate) fn now(value: Value) -> Reply {
        Reply::Now(value)
    }
}

pub(crate) type Handled = Result<Reply, ControlError>;
