use std::path::PathBuf;
use std::sync::mpsc::SyncSender;

use serde_json::Value;

use super::protocol;

/// How many engine ticks a deferred reply waits before it is reported as a
/// failure rather than left hanging.
const PENDING_TICKS: u32 = 600;

/// An effect a handler started that has not landed yet. Returning one is how a
/// handler says "reply when this is true", without knowing about request ids.
pub(crate) enum Effect {
    /// An editor was asked to open; the panel opens it on its next update.
    EditorOpen(&'static str),
    /// A capture was queued; the file appears once the draw pass has written it.
    Capture(PathBuf),
}

/// One held-back reply: the effect, and who is waiting for it.
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

    /// Send the reply if the effect has landed, or give up after enough ticks.
    /// `true` means this pending entry is finished with.
    pub(crate) fn resolve(
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
