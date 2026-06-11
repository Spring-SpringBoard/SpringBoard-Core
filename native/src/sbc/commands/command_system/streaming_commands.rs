use log::{error, warn};

use super::command::{Command, CommandId};
use super::history::{HistoryEntry, HistoryEvent};

/// Guards against streaming started but never stopped.
const MAX_STREAM_SIZE: usize = 100_000;

/// While streaming, executed commands are buffered here rather than pushed to
/// the undo history individually; stopping collapses them into one undo entry.
#[derive(Default)]
pub struct StreamingCommands {
    streaming: bool,
    buffer: Vec<HistoryEntry>,
}

pub(super) struct StoppedStream {
    pub entry: HistoryEntry,
    pub source_cmd_ids: Vec<CommandId>,
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

    pub(super) fn push(&mut self, entry: HistoryEntry) -> Vec<HistoryEvent> {
        if self.buffer.len() < MAX_STREAM_SIZE {
            self.buffer.push(entry);
            Vec::new()
        } else {
            warn!("stream hit cap {MAX_STREAM_SIZE}; dropping command");
            vec![HistoryEvent::Dropped { cmd_id: entry.id }]
        }
    }

    pub(super) fn stop(&mut self) -> Option<StoppedStream> {
        if !self.streaming {
            error!("not streaming");
            return None;
        }
        self.streaming = false;

        let buffered = std::mem::take(&mut self.buffer);
        let id = buffered.first()?.id;
        let source_cmd_ids = buffered.iter().map(|entry| entry.id).collect();
        let mut commands: Vec<Box<dyn Command>> =
            buffered.into_iter().map(|entry| entry.command).collect();
        let merger = commands.first()?.merger();
        Some(StoppedStream {
            entry: HistoryEntry::new(id, merger(std::mem::take(&mut commands))),
            source_cmd_ids,
        })
    }
}
