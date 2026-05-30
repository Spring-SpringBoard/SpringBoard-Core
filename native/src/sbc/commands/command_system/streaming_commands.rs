use log::{error, warn};

use super::command::Command;

/// Guards against streaming started but never stopped.
const MAX_STREAM_SIZE: usize = 100_000;

/// While streaming, executed commands are buffered here rather than pushed to
/// the undo history individually; stopping collapses them into one undo entry.
#[derive(Default)]
pub struct StreamingCommands {
    streaming: bool,
    buffer: Vec<Box<dyn Command>>,
}

impl StreamingCommands {
    pub fn is_streaming(&self) -> bool {
        self.streaming
    }

    pub fn start(&mut self) {
        if self.streaming {
            error!("already streaming");
            return;
        }
        self.streaming = true;
    }

    pub fn push(&mut self, cmd: Box<dyn Command>) {
        if self.buffer.len() < MAX_STREAM_SIZE {
            self.buffer.push(cmd);
        } else {
            warn!("stream hit cap {MAX_STREAM_SIZE}; dropping command");
        }
    }

    pub fn stop(&mut self) -> Option<Box<dyn Command>> {
        if !self.streaming {
            error!("not streaming");
            return None;
        }
        self.streaming = false;

        let buffered = std::mem::take(&mut self.buffer);
        let merger = buffered.first()?.merger();
        Some(merger(buffered))
    }
}
