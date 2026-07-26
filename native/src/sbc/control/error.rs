use super::channel::protocol;

/// Why a handler refused. Carries the JSON-RPC code the client distinguishes an
/// unknown name by; `dispatch` turns it into the wire error.
pub(crate) struct ControlError {
    pub code: i32,
    pub message: String,
}

impl ControlError {
    /// An editor, field, command or option that does not exist. The message
    /// should list what does.
    pub(crate) fn unknown(message: impl Into<String>) -> Self {
        ControlError {
            code: protocol::UNKNOWN_NAME,
            message: message.into(),
        }
    }

    /// Params that do not deserialize, or a value the field cannot hold.
    pub(crate) fn invalid(message: impl Into<String>) -> Self {
        ControlError {
            code: protocol::INVALID_PARAMS,
            message: message.into(),
        }
    }

    /// The editor understood and could not comply.
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
