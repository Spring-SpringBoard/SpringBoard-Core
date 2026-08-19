use std::path::PathBuf;
use std::sync::mpsc::SyncSender;

use serde_json::{json, Value};

use super::protocol;

const PENDING_TICKS: u32 = 600;

#[allow(dead_code)]
pub(crate) enum Effect {
    InputIdle {
        observed_input: u64,
        quiet_updates: u8,
    },
    EditorOpen(&'static str),
    DialogOpen(&'static str),
    DialogClosed(&'static str),
    Capture(PathBuf),
}

pub(crate) struct Pending {
    pub effect: Effect,
    id: Value,
    reply: SyncSender<String>,
    ticks_left: u32,
}

impl Pending {
    pub(crate) fn new(effect: Effect, id: Value, reply: SyncSender<String>) -> Self {
        Pending {
            effect,
            id,
            reply,
            ticks_left: PENDING_TICKS,
        }
    }

    fn resolve(
        &mut self,
        landed: bool,
        result: impl Fn() -> Value,
        timeout: impl Fn() -> String,
    ) -> bool {
        if landed {
            let _ = self.reply.send(protocol::result(&self.id, result()));
            return true;
        }
        self.ticks_left = self.ticks_left.saturating_sub(1);
        if self.ticks_left == 0 {
            let _ = self
                .reply
                .send(protocol::error(&self.id, protocol::FAILED, timeout()));
            return true;
        }
        false
    }
}

pub(crate) fn resolve_all(pending: &mut Vec<Pending>, input_epoch: u64) {
    let mut still_pending = Vec::new();
    for mut pending in std::mem::take(pending) {
        let input_idle = match &mut pending.effect {
            Effect::InputIdle {
                observed_input,
                quiet_updates,
            } => {
                if *observed_input != input_epoch {
                    *observed_input = input_epoch;
                    *quiet_updates = 0;
                } else {
                    *quiet_updates = quiet_updates.saturating_add(1);
                }
                Some(*quiet_updates >= 2)
            }
            _ => None,
        };
        let done = if let Some(ready) = input_idle {
            pending.resolve(
                ready,
                || json!({ "advanced": "input-idle" }),
                || "native input did not become idle".to_string(),
            )
        } else {
            match &pending.effect {
                Effect::Capture(path) => {
                    let path = path.clone();
                    pending.resolve(
                        path.is_file(),
                        || json!({ "path": path.to_string_lossy() }),
                        || format!("no capture was written to {}", path.display()),
                    )
                }
                Effect::InputIdle { .. } => {
                    unreachable!("handled before borrowing the pending reply")
                }
                _ => pending.resolve(
                    false,
                    || json!(null),
                    || "effect not supported in this build".to_string(),
                ),
            }
        };
        if !done {
            still_pending.push(pending);
        }
    }
    *pending = still_pending;
}
