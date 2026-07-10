use log::{debug, warn};
use serde::Deserialize;
use spring_native::prelude::NativeInterfaceRef;

const PORT_FLAGS_PATH: &str = "port_flags.json";

#[derive(Debug, Deserialize)]
struct PortFlags {
    #[serde(default)]
    chonsole: PortImpl,
    #[serde(default)]
    ui: UiImpl,
}

#[derive(Debug, Clone, Copy, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub(crate) enum PortImpl {
    #[default]
    Lua,
    Rust,
}

/// Which implementation owns the editor UI. The three are independent: exactly
/// one of them builds a UI, the other two build nothing.
#[derive(Debug, Clone, Copy, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub(crate) enum UiImpl {
    #[default]
    Chili,
    RmlUi,
    Rust,
}

pub(crate) fn chonsole_impl(interface: &NativeInterfaceRef) -> PortImpl {
    read_flag(interface, "chonsole", |f| f.chonsole)
}

pub(crate) fn ui_impl(interface: &NativeInterfaceRef) -> UiImpl {
    read_flag(interface, "ui", |f| f.ui)
}

fn read_flag<T: std::fmt::Debug + Default>(
    interface: &NativeInterfaceRef,
    name: &str,
    extract: fn(&PortFlags) -> T,
) -> T {
    let bytes = match interface.vfs().load_file(PORT_FLAGS_PATH, "") {
        Ok(bytes) if !bytes.is_empty() => bytes,
        Ok(_) => return T::default(),
        Err(err) => {
            warn!("failed to read {PORT_FLAGS_PATH}: {err:?}");
            return T::default();
        }
    };
    let flags = match serde_json::from_slice::<PortFlags>(&bytes) {
        Ok(flags) => flags,
        Err(err) => {
            warn!("failed to parse {PORT_FLAGS_PATH}: {err}");
            return T::default();
        }
    };
    let value = extract(&flags);
    debug!("{PORT_FLAGS_PATH}: {name}={value:?}");
    value
}
