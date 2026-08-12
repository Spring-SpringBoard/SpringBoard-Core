use log::{debug, warn};
use serde::Deserialize;
use spring_native::prelude::NativeInterfaceRef;

const PORT_FLAGS_PATH: &str = "port_flags.json";

#[derive(Debug, Deserialize)]
struct PortFlags {
    #[serde(default)]
    ui: UiImpl,
}

#[derive(Debug, Clone, Copy, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub(crate) enum UiImpl {
    #[default]
    Chili,
    Rust,
}

pub(crate) fn ui_impl(interface: &NativeInterfaceRef) -> UiImpl {
    let bytes = match interface.vfs().load_file(PORT_FLAGS_PATH, "") {
        Ok(bytes) if !bytes.is_empty() => bytes,
        Ok(_) => return UiImpl::default(),
        Err(err) => {
            warn!("failed to read {PORT_FLAGS_PATH}: {err:?}");
            return UiImpl::default();
        }
    };
    let flags = match serde_json::from_slice::<PortFlags>(&bytes) {
        Ok(flags) => flags,
        Err(err) => {
            warn!("failed to parse {PORT_FLAGS_PATH}: {err}");
            return UiImpl::default();
        }
    };
    debug!("{PORT_FLAGS_PATH}: ui={:?}", flags.ui);
    flags.ui
}
