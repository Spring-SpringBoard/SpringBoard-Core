#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum Event {
    AddConsoleLine,
    CommandApplied,
    CommandHistoryChanged,
    CommandRecorded,
    DrawScreen,
    DrawScreenPost,
    DrawWorld,
    DrawWorldPreUnit,
    KeyPress,
    KeyRelease,
    MouseMove,
    MousePress,
    MouseRelease,
    MouseWheel,
    TextInput,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum ListenerId {
    DevConsole,
    InputTracker,
    Screenshot,
}

impl ListenerId {
    pub(super) fn event_priority(self, event: Event) -> i16 {
        match (self, event) {
            (Self::InputTracker, _) => -100,
            (Self::DevConsole, Event::KeyPress) => 10,
            _ => 0,
        }
    }
}
