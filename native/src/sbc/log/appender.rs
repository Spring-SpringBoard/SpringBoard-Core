//! A custom log4rs appender (`kind: spring_echo` in `log4rs.yaml`) that routes
//! formatted log records to the engine console via `echo_to_spring`.

use log::Record;
use log4rs::{
    append::Append,
    config::{Deserialize, Deserializers},
    encode::{pattern::PatternEncoder, writer::simple::SimpleWriter, Encode},
};

use super::setup::echo_to_spring;

/// Make `kind: spring_echo` resolvable when log4rs parses the YAML.
pub fn register(deserializers: &mut Deserializers) {
    deserializers.insert("spring_echo", SpringEchoAppenderDeserializer);
}

#[derive(Debug)]
struct SpringEchoAppender {
    encoder: Box<dyn Encode>,
}

impl Append for SpringEchoAppender {
    fn append(&self, record: &Record) -> anyhow::Result<()> {
        let mut buffer = Vec::new();
        {
            let mut writer = SimpleWriter(&mut buffer);
            self.encoder.encode(&mut writer, record)?;
        }

        let message = match String::from_utf8(buffer) {
            Ok(mut msg) => {
                while msg.ends_with(['\n', '\r']) {
                    msg.pop();
                }
                msg
            }
            Err(err) => format!("<invalid log utf8: {err}>"),
        };

        echo_to_spring(&message);
        Ok(())
    }

    fn flush(&self) {}
}

#[derive(Debug, serde::Deserialize)]
#[serde(deny_unknown_fields)]
struct SpringEchoAppenderConfig {
    encoder: Option<log4rs::encode::EncoderConfig>,
}

#[derive(Debug, Default, Copy, Clone)]
struct SpringEchoAppenderDeserializer;

impl Deserialize for SpringEchoAppenderDeserializer {
    type Trait = dyn Append;
    type Config = SpringEchoAppenderConfig;

    fn deserialize(
        &self,
        config: SpringEchoAppenderConfig,
        deserializers: &Deserializers,
    ) -> anyhow::Result<Box<dyn Append>> {
        let encoder: Box<dyn Encode> = match config.encoder {
            Some(encoder) => deserializers.deserialize(&encoder.kind, encoder.config)?,
            None => Box::<PatternEncoder>::default(),
        };
        Ok(Box::new(SpringEchoAppender { encoder }))
    }
}
