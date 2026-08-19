use super::channel::protocol;

pub(crate) struct ControlError {
    pub code: i32,
    pub message: String,
}

impl ControlError {
    pub(crate) fn unknown(message: impl Into<String>) -> Self {
        ControlError {
            code: protocol::UNKNOWN_NAME,
            message: message.into(),
        }
    }

    pub(crate) fn invalid(message: impl Into<String>) -> Self {
        ControlError {
            code: protocol::INVALID_PARAMS,
            message: message.into(),
        }
    }

    pub(crate) fn failed(message: impl Into<String>) -> Self {
        ControlError {
            code: protocol::FAILED,
            message: message.into(),
        }
    }

    pub(crate) fn no_such_method(method: &str) -> Self {
        ControlError {
            code: protocol::METHOD_NOT_FOUND,
            message: format!("no such method: {method}"),
        }
    }
}
