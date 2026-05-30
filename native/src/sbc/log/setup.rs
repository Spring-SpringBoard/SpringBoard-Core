use std::sync::OnceLock;

use log::{Level, LevelFilter, Metadata, Record};

use spring_native::prelude::*;

use super::appender;

// Set once at startup; used by every echo to the engine console.
static INTERFACE: OnceLock<NativeInterfaceRef> = OnceLock::new();

/// Wire up logging: record the engine interface for `echo`, then install the
/// embedded log4rs config (falling back to a plain Spring logger if it fails).
pub fn init(interface: NativeInterfaceRef) {
    let _ = INTERFACE.set(interface);
    setup_log4rs(&interface);
}

pub(super) fn echo_to_spring(msg: &str) {
    if let Some(interface) = INTERFACE.get() {
        let messages = interface.messages();
        let _ = messages.echo(msg, "");
    }
}

fn setup_log4rs(interface: &NativeInterfaceRef) {
    match init_log4rs_from_embedded() {
        Ok(()) => {
            let messages = interface.messages();
            let _ = messages.echo("log4rs config loaded from embedded YAML.", "");
        }
        Err(err) => {
            let messages = interface.messages();
            let _ = messages.echo(
                &format!("log4rs init failed: {err}. Falling back to Spring logger."),
                "",
            );

            log::set_boxed_logger(Box::new(SpringLogger))
                .map(|()| log::set_max_level(LevelFilter::Info))
                .expect("Failed to setup Spring Logger");
        }
    }
}

fn init_log4rs_from_embedded() -> Result<(), String> {
    const EMBEDDED_LOG4RS: &str = include_str!("../../../log4rs.yaml");

    let raw: log4rs::config::RawConfig =
        serde_yaml::from_str(EMBEDDED_LOG4RS).map_err(|err| err.to_string())?;

    let mut deserializers = log4rs::config::Deserializers::default();
    appender::register(&mut deserializers);

    let (appenders, errors) = raw.appenders_lossy(&deserializers);
    if !errors.is_empty() {
        return Err(format!("log4rs appenders error: {errors:?}"));
    }

    let config = log4rs::config::Config::builder()
        .appenders(appenders)
        .loggers(raw.loggers())
        .build(raw.root())
        .map_err(|err| err.to_string())?;

    log4rs::config::init_config(config)
        .map(|_| ())
        .map_err(|err| err.to_string())
}

/// Fallback used only if the log4rs config fails to load.
struct SpringLogger;

impl log::Log for SpringLogger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        metadata.level() <= Level::Trace
    }

    fn log(&self, record: &Record) {
        if self.enabled(record.metadata()) {
            echo_to_spring(&format!("{} - {}", record.level(), record.args()));
        }
    }

    fn flush(&self) {}
}

#[cfg(test)]
mod tests {
    #[test]
    fn embedded_log4rs_config_is_valid() {
        const EMBEDDED_LOG4RS: &str = include_str!("../../../log4rs.yaml");
        serde_yaml::from_str::<log4rs::config::RawConfig>(EMBEDDED_LOG4RS)
            .expect("embedded log4rs.yaml should deserialize");
    }
}
