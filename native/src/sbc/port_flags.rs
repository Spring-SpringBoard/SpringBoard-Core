use log::{debug, warn};
use serde::Deserialize;
use spring_native::prelude::NativeInterfaceRef;

const PORT_FLAGS_PATH: &str = "port_flags.json";

#[derive(Debug, Deserialize)]
struct PortFlags {
    #[serde(default)]
    chonsole: PortImpl,
}

#[derive(Debug, Clone, Copy, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub(crate) enum PortImpl {
    #[default]
    Lua,
    Rust,
}

pub(crate) fn chonsole_impl(interface: &NativeInterfaceRef) -> PortImpl {
    let bytes = match interface.vfs().load_file(PORT_FLAGS_PATH, "") {
        Ok(bytes) if !bytes.is_empty() => bytes,
        Ok(_) => return PortImpl::Lua,
        Err(err) => {
            warn!("failed to read {PORT_FLAGS_PATH}: {err:?}");
            return PortImpl::Lua;
        }
    };
    let flags = match serde_json::from_slice::<PortFlags>(&bytes) {
        Ok(flags) => flags,
        Err(err) => {
            warn!("failed to parse {PORT_FLAGS_PATH}: {err}");
            return PortImpl::Lua;
        }
    };
    debug!("{PORT_FLAGS_PATH}: chonsole={:?}", flags.chonsole);
    flags.chonsole
}
